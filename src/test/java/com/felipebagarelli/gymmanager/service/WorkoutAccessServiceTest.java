package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;

@ExtendWith(MockitoExtension.class)
class WorkoutAccessServiceTest {

    @Mock
    private TrainerStudentRepository trainerStudentRepository;

    @Mock
    private StudentProfileRepository studentProfileRepository;

    @Mock
    private WorkoutAssignmentRepository workoutAssignmentRepository;

    @InjectMocks
    private WorkoutAccessService accessService;

    private Workout workout;

    @BeforeEach
    void setUp() {
        User trainerUser = User.builder().email("trainer@example.com").role(Role.TRAINER).build();
        User studentUser = User.builder().email("aluno@example.com").role(Role.STUDENT).build();
        StudentProfile student = StudentProfile.builder().id(2L).user(studentUser).build();
        TrainerProfile trainer = TrainerProfile.builder().id(1L).user(trainerUser).build();
        TrainerStudent link = TrainerStudent.builder().trainer(trainer).student(student).build();
        workout = Workout.builder().id(10L).name("Treino A").trainer(trainer).build();

        lenient().when(trainerStudentRepository.findByStudentId(2L)).thenReturn(Optional.of(link));
        lenient().when(studentProfileRepository.findById(2L)).thenReturn(Optional.of(student));
        lenient().when(workoutAssignmentRepository.existsByWorkoutIdAndStudentUserEmail(10L, "aluno@example.com"))
                .thenReturn(true);
    }

    @Test
    void assertCanWrite_allowsOwningTrainer() {
        assertThatCode(() -> accessService.assertCanWrite(2L, "trainer@example.com")).doesNotThrowAnyException();
    }

    @Test
    void assertCanWrite_deniesAnotherTrainerAndTheStudent() {
        assertThatThrownBy(() -> accessService.assertCanWrite(2L, "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> accessService.assertCanWrite(2L, "aluno@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void assertCanRead_allowsOwningTrainerAndTheStudentThemselves() {
        assertThatCode(() -> accessService.assertCanRead(2L, "trainer@example.com")).doesNotThrowAnyException();
        assertThatCode(() -> accessService.assertCanRead(2L, "aluno@example.com")).doesNotThrowAnyException();
    }

    @Test
    void assertCanRead_deniesUnrelatedUser() {
        assertThatThrownBy(() -> accessService.assertCanRead(2L, "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void assertCanRead_throwsNotFound_whenStudentDoesNotExist() {
        assertThatThrownBy(() -> accessService.assertCanRead(99L, "trainer@example.com"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void assertOwnsWorkout_allowsOnlyTheTemplateTrainer() {
        assertThatCode(() -> accessService.assertOwnsWorkout(workout, "trainer@example.com")).doesNotThrowAnyException();
        assertThatThrownBy(() -> accessService.assertOwnsWorkout(workout, "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> accessService.assertOwnsWorkout(workout, "aluno@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void assertOwnsWorkout_deniesLegacyWorkoutWithoutTrainer() {
        Workout legacy = Workout.builder().id(11L).name("Legado").build();
        assertThatThrownBy(() -> accessService.assertOwnsWorkout(legacy, "trainer@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void assertCanReadWorkout_allowsOwnerAndAssignedStudentOnly() {
        assertThatCode(() -> accessService.assertCanReadWorkout(workout, "trainer@example.com")).doesNotThrowAnyException();
        assertThatCode(() -> accessService.assertCanReadWorkout(workout, "aluno@example.com")).doesNotThrowAnyException();
        assertThatThrownBy(() -> accessService.assertCanReadWorkout(workout, "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }
}
