package com.felipebagarelli.gymmanager.student.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.EmailAlreadyInUseException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.dto.request.CreateStudentRequest;
import com.felipebagarelli.gymmanager.student.dto.response.StudentProfileResponse;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StudentServiceTest {

    @Mock
    private StudentProfileRepository studentProfileRepository;

    @Mock
    private TrainerStudentRepository trainerStudentRepository;

    @Mock
    private TrainerProfileRepository trainerProfileRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private StudentService studentService;

    private TrainerProfile trainer() {
        User trainerUser = User.builder().email("trainer@example.com").role(Role.TRAINER).build();
        return TrainerProfile.builder().id(1L).user(trainerUser).displayName("João Personal").build();
    }

    @Test
    void createStudent_throwsResourceNotFoundException_whenTrainerNotFound() {
        CreateStudentRequest request = new CreateStudentRequest(
                "aluno@example.com", "senhaSegura123", "Maria Aluna", LocalDate.of(2000, 1, 1), "11988888888", "hipertrofia", 1.65, 60.0);

        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> studentService.createStudent(1L, request, "trainer@example.com"))
                .isInstanceOf(ResourceNotFoundException.class);

        verify(userRepository, never()).save(any());
    }

    @Test
    void createStudent_throwsAccessDeniedException_whenAuthenticatedEmailIsNotTheTrainerOwner() {
        CreateStudentRequest request = new CreateStudentRequest(
                "aluno@example.com", "senhaSegura123", "Maria Aluna", LocalDate.of(2000, 1, 1), "11988888888", "hipertrofia", 1.65, 60.0);

        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(trainer()));

        assertThatThrownBy(() -> studentService.createStudent(1L, request, "outro-trainer@example.com"))
                .isInstanceOf(AccessDeniedException.class);

        verify(userRepository, never()).save(any());
    }

    @Test
    void createStudent_throwsEmailAlreadyInUseException_whenEmailExists() {
        CreateStudentRequest request = new CreateStudentRequest(
                "aluno@example.com", "senhaSegura123", "Maria Aluna", LocalDate.of(2000, 1, 1), "11988888888", "hipertrofia", 1.65, 60.0);

        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(trainer()));
        when(userRepository.existsByEmail(request.email())).thenReturn(true);

        assertThatThrownBy(() -> studentService.createStudent(1L, request, "trainer@example.com"))
                .isInstanceOf(EmailAlreadyInUseException.class);

        verify(userRepository, never()).save(any());
        verify(studentProfileRepository, never()).save(any());
        verify(trainerStudentRepository, never()).save(any());
    }

    @Test
    void createStudent_savesUserStudentProfileAndActiveLink_whenValid() {
        CreateStudentRequest request = new CreateStudentRequest(
                "aluno@example.com", "senhaSegura123", "Maria Aluna", LocalDate.of(2000, 1, 1), "11988888888", "hipertrofia", 1.65, 60.0);

        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(trainer()));
        when(userRepository.existsByEmail(request.email())).thenReturn(false);
        when(passwordEncoder.encode(request.password())).thenReturn("hashed-password");
        when(studentProfileRepository.save(any(StudentProfile.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(trainerStudentRepository.save(any(TrainerStudent.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        StudentProfileResponse response = studentService.createStudent(1L, request, "trainer@example.com");

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        assertThat(userCaptor.getValue().getRole()).isEqualTo(Role.STUDENT);
        assertThat(userCaptor.getValue().getPasswordHash()).isEqualTo("hashed-password");

        ArgumentCaptor<TrainerStudent> linkCaptor = ArgumentCaptor.forClass(TrainerStudent.class);
        verify(trainerStudentRepository).save(linkCaptor.capture());
        assertThat(linkCaptor.getValue().getStatus()).isEqualTo(TrainerStudentStatus.ACTIVE);
        assertThat(linkCaptor.getValue().getTrainer().getId()).isEqualTo(1L);

        assertThat(response.email()).isEqualTo("aluno@example.com");
        assertThat(response.name()).isEqualTo("Maria Aluna");
        assertThat(response.status()).isEqualTo(TrainerStudentStatus.ACTIVE);
    }

    @Test
    void listByTrainer_throwsResourceNotFoundException_whenTrainerNotFound() {
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> studentService.listByTrainer(1L, "trainer@example.com"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void listByTrainer_throwsAccessDeniedException_whenAuthenticatedEmailIsNotTheTrainerOwner() {
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(trainer()));

        assertThatThrownBy(() -> studentService.listByTrainer(1L, "outro-trainer@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void listByTrainer_returnsMappedStudents_whenTrainerExists() {
        User user = User.builder().email("aluno@example.com").role(Role.STUDENT).build();
        StudentProfile student = StudentProfile.builder().id(2L).user(user).name("Maria Aluna").build();
        TrainerStudent link = TrainerStudent.builder()
                .trainer(trainer())
                .student(student)
                .status(TrainerStudentStatus.ACTIVE)
                .build();

        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(trainer()));
        when(trainerStudentRepository.findByTrainerId(1L)).thenReturn(List.of(link));

        List<StudentProfileResponse> responses = studentService.listByTrainer(1L, "trainer@example.com");

        assertThat(responses).hasSize(1);
        assertThat(responses.get(0).name()).isEqualTo("Maria Aluna");
        assertThat(responses.get(0).status()).isEqualTo(TrainerStudentStatus.ACTIVE);
    }

    @Test
    void getById_throwsResourceNotFoundException_whenStudentNotFound() {
        when(studentProfileRepository.findById(2L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> studentService.getById(2L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void getById_returnsResponseWithStatus_whenFound() {
        User user = User.builder().email("aluno@example.com").role(Role.STUDENT).build();
        StudentProfile student = StudentProfile.builder().id(2L).user(user).name("Maria Aluna").build();
        TrainerStudent link = TrainerStudent.builder()
                .trainer(trainer())
                .student(student)
                .status(TrainerStudentStatus.PAUSED)
                .build();

        when(studentProfileRepository.findById(2L)).thenReturn(Optional.of(student));
        when(trainerStudentRepository.findByStudentId(2L)).thenReturn(Optional.of(link));

        StudentProfileResponse response = studentService.getById(2L);

        assertThat(response.name()).isEqualTo("Maria Aluna");
        assertThat(response.status()).isEqualTo(TrainerStudentStatus.PAUSED);
    }

    @Test
    void getMyProfile_returnsTheAuthenticatedStudentWithLinkStatus() {
        User user = User.builder().email("aluno@example.com").role(Role.STUDENT).build();
        StudentProfile student = StudentProfile.builder().id(2L).user(user).name("Maria Aluna").active(true).build();
        TrainerStudent link = TrainerStudent.builder().trainer(trainer()).student(student)
                .status(TrainerStudentStatus.ACTIVE).build();

        when(studentProfileRepository.findByUserEmail("aluno@example.com")).thenReturn(Optional.of(student));
        when(trainerStudentRepository.findByStudentId(2L)).thenReturn(Optional.of(link));

        StudentProfileResponse response = studentService.getMyProfile("aluno@example.com");

        assertThat(response.id()).isEqualTo(2L);
        assertThat(response.email()).isEqualTo("aluno@example.com");
        assertThat(response.status()).isEqualTo(TrainerStudentStatus.ACTIVE);
    }

    @Test
    void getMyProfile_throwsNotFound_whenUserHasNoStudentProfile() {
        when(studentProfileRepository.findByUserEmail("trainer@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> studentService.getMyProfile("trainer@example.com"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    private TrainerStudent linkWithGoal(Integer goal) {
        User user = User.builder().email("aluno@example.com").role(Role.STUDENT).build();
        StudentProfile student = StudentProfile.builder().id(2L).user(user).name("Maria Aluna").weeklyGoal(goal).build();
        TrainerStudent link = TrainerStudent.builder().trainer(trainer()).student(student)
                .status(TrainerStudentStatus.ACTIVE).build();
        when(trainerStudentRepository.findByStudentId(2L)).thenReturn(Optional.of(link));
        return link;
    }

    @Test
    void updateById_setsWeeklyGoal_whenProvided() {
        TrainerStudent link = linkWithGoal(null);

        StudentProfileResponse response = studentService.updateById(2L,
                new com.felipebagarelli.gymmanager.student.dto.request.UpdateStudentRequest(
                        "Maria Aluna", null, null, null, null, null, 4), "trainer@example.com");

        assertThat(response.weeklyGoal()).isEqualTo(4);
        assertThat(link.getStudent().getWeeklyGoal()).isEqualTo(4);
    }

    @Test
    void updateById_keepsExistingWeeklyGoal_whenRequestOmitsIt() {
        linkWithGoal(3);

        StudentProfileResponse response = studentService.updateById(2L,
                new com.felipebagarelli.gymmanager.student.dto.request.UpdateStudentRequest(
                        "Maria Aluna", null, null, null, null, null, null), "trainer@example.com");

        assertThat(response.weeklyGoal()).isEqualTo(3);
    }
}
