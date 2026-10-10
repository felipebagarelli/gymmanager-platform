package com.felipebagarelli.gymmanager.session.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.service.WorkoutAccessService;
import com.felipebagarelli.gymmanager.session.dto.PerformanceResponse;
import com.felipebagarelli.gymmanager.session.dto.RecordPerformanceRequest;
import com.felipebagarelli.gymmanager.session.dto.UpdatePerformanceRequest;
import com.felipebagarelli.gymmanager.session.entity.Effort;
import com.felipebagarelli.gymmanager.session.dto.WorkoutSessionResponse;
import com.felipebagarelli.gymmanager.session.entity.ExercisePerformance;
import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WorkoutSessionServiceTest {

    private static final String STUDENT = "aluno@example.com";

    @Mock
    private WorkoutSessionRepository sessionRepository;
    @Mock
    private ExercisePerformanceRepository performanceRepository;
    @Mock
    private WorkoutAssignmentRepository assignmentRepository;
    @Mock
    private WorkoutExercisesRepository workoutExercisesRepository;
    @Mock
    private WorkoutAccessService workoutAccessService;

    @Mock
    private com.felipebagarelli.gymmanager.billing.service.BillingAccessGuard billingAccessGuard;

    @InjectMocks
    private WorkoutSessionService service;

    private WorkoutAssignment assignment;
    private WorkoutSession openSession;
    private WorkoutExercises exerciseOfWorkout;

    @BeforeEach
    void setUp() {
        User studentUser = User.builder().email(STUDENT).role(Role.STUDENT).build();
        StudentProfile student = StudentProfile.builder().id(2L).user(studentUser).build();
        Workout workout = Workout.builder().id(10L).name("Treino A").build();
        assignment = WorkoutAssignment.builder().id(5L).workout(workout).student(student)
                .status(WorkoutAssignmentStatus.ACTIVE).build();
        openSession = WorkoutSession.builder().id(7L).assignment(assignment).startedAt(LocalDateTime.now()).build();
        exerciseOfWorkout = WorkoutExercises.builder().id(30L).workout(workout).build();
    }

    @Test
    void start_createsSession_whenWorkoutIsActivelyAssignedToTheStudent() {
        when(assignmentRepository.findByWorkoutIdAndStudentUserEmailAndStatus(10L, STUDENT, WorkoutAssignmentStatus.ACTIVE))
                .thenReturn(Optional.of(assignment));
        when(sessionRepository.existsByAssignmentIdAndFinishedAtIsNull(5L)).thenReturn(false);
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(i -> {
            WorkoutSession s = i.getArgument(0);
            s.setId(7L);
            return s;
        });
        when(performanceRepository.findBySessionIdOrderByIdAsc(7L)).thenReturn(List.of());

        WorkoutSessionResponse response = service.start(10L, STUDENT);

        assertThat(response.workoutId()).isEqualTo(10L);
        assertThat(response.studentId()).isEqualTo(2L);
        assertThat(response.startedAt()).isNotNull();
        assertThat(response.finishedAt()).isNull();
    }

    @Test
    void start_isDenied_whenWorkoutIsNotAssignedToTheStudent() {
        when(assignmentRepository.findByWorkoutIdAndStudentUserEmailAndStatus(10L, "outro@example.com", WorkoutAssignmentStatus.ACTIVE))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.start(10L, "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
        verify(sessionRepository, never()).save(any());
    }

    @Test
    void start_conflicts_whenThereIsAlreadyAnOpenSession() {
        when(assignmentRepository.findByWorkoutIdAndStudentUserEmailAndStatus(10L, STUDENT, WorkoutAssignmentStatus.ACTIVE))
                .thenReturn(Optional.of(assignment));
        when(sessionRepository.existsByAssignmentIdAndFinishedAtIsNull(5L)).thenReturn(true);

        assertThatThrownBy(() -> service.start(10L, STUDENT)).isInstanceOf(ConflictException.class);
    }

    @Test
    void addPerformance_savesSet_forExerciseOfTheSessionWorkout() {
        when(sessionRepository.findById(7L)).thenReturn(Optional.of(openSession));
        when(workoutExercisesRepository.findById(30L)).thenReturn(Optional.of(exerciseOfWorkout));
        when(performanceRepository.save(any(ExercisePerformance.class))).thenAnswer(i -> {
            ExercisePerformance p = i.getArgument(0);
            p.setId(99L);
            return p;
        });

        PerformanceResponse response = service.addPerformance(7L, new RecordPerformanceRequest(30L, 1, 12, 20.0, com.felipebagarelli.gymmanager.session.entity.Effort.HARD), STUDENT);

        assertThat(response.id()).isEqualTo(99L);
        assertThat(response.reps()).isEqualTo(12);
        assertThat(response.loadKg()).isEqualTo(20.0);
        assertThat(response.effort()).isEqualTo(com.felipebagarelli.gymmanager.session.entity.Effort.HARD);
    }

    @Test
    void addPerformance_isDenied_forAnotherUser_includingTheTrainer() {
        when(sessionRepository.findById(7L)).thenReturn(Optional.of(openSession));

        assertThatThrownBy(() -> service.addPerformance(7L, new RecordPerformanceRequest(30L, 1, 12, 20.0, null), "trainer@example.com"))
                .isInstanceOf(AccessDeniedException.class);
        verify(performanceRepository, never()).save(any());
    }

    @Test
    void addPerformance_conflicts_whenSessionIsFinished() {
        openSession.setFinishedAt(LocalDateTime.now());
        when(sessionRepository.findById(7L)).thenReturn(Optional.of(openSession));

        assertThatThrownBy(() -> service.addPerformance(7L, new RecordPerformanceRequest(30L, 1, 12, 20.0, null), STUDENT))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void addPerformance_rejectsExerciseFromAnotherWorkout() {
        Workout other = Workout.builder().id(99L).build();
        WorkoutExercises foreign = WorkoutExercises.builder().id(31L).workout(other).build();
        when(sessionRepository.findById(7L)).thenReturn(Optional.of(openSession));
        when(workoutExercisesRepository.findById(31L)).thenReturn(Optional.of(foreign));

        assertThatThrownBy(() -> service.addPerformance(7L, new RecordPerformanceRequest(31L, 1, 12, 20.0, null), STUDENT))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    private ExercisePerformance savedSet(Effort effort) {
        ExercisePerformance set = ExercisePerformance.builder().id(99L).session(openSession).workoutExercise(exerciseOfWorkout)
                .setNumber(1).reps(10).loadKg(20.0).effort(effort).build();
        when(sessionRepository.findById(7L)).thenReturn(Optional.of(openSession));
        when(performanceRepository.findById(99L)).thenReturn(Optional.of(set));
        when(performanceRepository.save(any(ExercisePerformance.class))).thenAnswer(i -> i.getArgument(0));
        return set;
    }

    @Test
    void updatePerformance_withoutEffortField_keepsTheStoredEffort() {
        ExercisePerformance set = savedSet(Effort.HARD);

        PerformanceResponse response = service.updatePerformance(7L, 99L, new UpdatePerformanceRequest(1, 12, 25.0, null, null), STUDENT);

        assertThat(response.reps()).isEqualTo(12);
        assertThat(response.loadKg()).isEqualTo(25.0);
        assertThat(response.effort()).isEqualTo(Effort.HARD);
        assertThat(set.getEffort()).isEqualTo(Effort.HARD);
    }

    @Test
    void updatePerformance_withEffort_replacesIt() {
        savedSet(Effort.HARD);

        PerformanceResponse response = service.updatePerformance(7L, 99L, new UpdatePerformanceRequest(1, 10, 20.0, Effort.EASY, null), STUDENT);

        assertThat(response.effort()).isEqualTo(Effort.EASY);
    }

    @Test
    void updatePerformance_withClearEffort_removesIt() {
        savedSet(Effort.HARD);

        PerformanceResponse response = service.updatePerformance(7L, 99L, new UpdatePerformanceRequest(1, 10, 20.0, null, true), STUDENT);

        assertThat(response.effort()).isNull();
    }

    @Test
    void updatePerformance_clearEffortIsIgnoredWhenAnEffortIsSent() {
        savedSet(Effort.HARD);

        PerformanceResponse response = service.updatePerformance(7L, 99L, new UpdatePerformanceRequest(1, 10, 20.0, Effort.IDEAL, true), STUDENT);

        assertThat(response.effort()).isEqualTo(Effort.IDEAL);
    }

    @Test
    void finish_setsFinishedAt_andCannotBeFinishedTwice() {
        when(sessionRepository.findById(7L)).thenReturn(Optional.of(openSession));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(i -> i.getArgument(0));
        when(performanceRepository.findBySessionIdOrderByIdAsc(7L)).thenReturn(List.of());

        WorkoutSessionResponse response = service.finish(7L, STUDENT);

        assertThat(response.finishedAt()).isNotNull();
        assertThatThrownBy(() -> service.finish(7L, STUDENT)).isInstanceOf(ConflictException.class);
    }

    @Test
    void getById_delegatesReadPermissionToAccessService() {
        when(sessionRepository.findById(7L)).thenReturn(Optional.of(openSession));
        doThrow(new AccessDeniedException("negado")).when(workoutAccessService).assertCanRead(2L, "outro@example.com");

        assertThatThrownBy(() -> service.getById(7L, "outro@example.com")).isInstanceOf(AccessDeniedException.class);
    }
}
