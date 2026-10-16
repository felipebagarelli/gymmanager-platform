package com.felipebagarelli.gymmanager.student.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.dto.response.StudentProfileResponse;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Reativar aluno e pausar/retomar o vinculo (B2.2). */
@ExtendWith(MockitoExtension.class)
class StudentLinkStatusTest {

    @Mock private StudentProfileRepository studentProfileRepository;
    @Mock private TrainerStudentRepository trainerStudentRepository;
    @Mock private TrainerProfileRepository trainerProfileRepository;
    @Mock private UserRepository userRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private WorkoutSessionRepository sessionRepository;

    @InjectMocks private StudentService studentService;

    private StudentProfile student;
    private TrainerStudent link;

    @BeforeEach
    void setUp() {
        TrainerProfile trainer = TrainerProfile.builder().id(1L)
                .user(User.builder().email("trainer@example.com").role(Role.TRAINER).build()).build();
        student = StudentProfile.builder().id(2L).name("Maria Aluna").active(false)
                .user(User.builder().email("aluno@example.com").role(Role.STUDENT).build()).build();
        link = TrainerStudent.builder().trainer(trainer).student(student).status(TrainerStudentStatus.ACTIVE).build();
        when(trainerStudentRepository.findByStudentId(2L)).thenReturn(Optional.of(link));
    }

    @Test
    void reactivate_turnsTheStudentActiveAgain() {
        StudentProfileResponse response = studentService.reactivate(2L, "trainer@example.com");

        assertThat(student.isActive()).isTrue();
        verify(studentProfileRepository).save(student);
        assertThat(response.active()).isTrue();
    }

    @Test
    void reactivate_onlyTheOwningTrainer() {
        assertThatThrownBy(() -> studentService.reactivate(2L, "outro@example.com")).isInstanceOf(AccessDeniedException.class);
        assertThat(student.isActive()).isFalse();
    }

    @Test
    void pauseAndResume() {
        StudentProfileResponse paused = studentService.updateLinkStatus(2L, TrainerStudentStatus.PAUSED, "trainer@example.com");
        assertThat(link.getStatus()).isEqualTo(TrainerStudentStatus.PAUSED);
        assertThat(paused.status()).isEqualTo(TrainerStudentStatus.PAUSED);

        studentService.updateLinkStatus(2L, TrainerStudentStatus.ACTIVE, "trainer@example.com");
        assertThat(link.getStatus()).isEqualTo(TrainerStudentStatus.ACTIVE);
    }

    @Test
    void linkStatus_onlyActiveOrPaused() {
        assertThatThrownBy(() -> studentService.updateLinkStatus(2L, TrainerStudentStatus.CANCELED, "trainer@example.com"))
                .isInstanceOf(BadRequestException.class);

        link.setStatus(TrainerStudentStatus.CANCELED);
        assertThatThrownBy(() -> studentService.updateLinkStatus(2L, TrainerStudentStatus.ACTIVE, "trainer@example.com"))
                .isInstanceOf(ConflictException.class);
        verify(trainerStudentRepository, never()).save(any());
    }

    @Test
    void linkStatus_onlyTheOwningTrainer() {
        assertThatThrownBy(() -> studentService.updateLinkStatus(2L, TrainerStudentStatus.PAUSED, "aluno@example.com"))
                .isInstanceOf(AccessDeniedException.class);
        assertThat(link.getStatus()).isEqualTo(TrainerStudentStatus.ACTIVE);
    }
}
