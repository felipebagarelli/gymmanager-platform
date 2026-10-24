package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.billing.service.BillingAccessGuard;
import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutExerciseRequest;
import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** C6: aluno sem personal monta e mantem os proprios treinos. */
class StudentOwnedWorkoutTest {

    private static final String ANA = "ana@example.com";

    private final List<Workout> workouts = new ArrayList<>();
    private final List<WorkoutAssignment> assignments = new ArrayList<>();
    private final AtomicLong ids = new AtomicLong(10);
    private StudentProfile ana;
    private TrainerStudentRepository links;
    private WorkoutRepository workoutRepository;
    private WorkoutSessionRepository sessions;
    private WorkoutExercisesRepository planRepository;
    private ExerciseRepository exerciseRepository;
    private WorkoutService service;
    private WorkoutExerciseService planService;

    @BeforeEach
    void setUp() {
        ana = StudentProfile.builder().id(9L).name("Ana")
                .user(User.builder().email(ANA).role(Role.STUDENT).build()).build();
        StudentProfileRepository students = mock(StudentProfileRepository.class);
        when(students.findByUserEmail(ANA)).thenReturn(Optional.of(ana));
        TrainerProfileRepository trainers = mock(TrainerProfileRepository.class);
        when(trainers.findByUserEmail(ANA)).thenReturn(Optional.empty());
        links = mock(TrainerStudentRepository.class);
        when(links.findByStudentId(anyLong())).thenReturn(Optional.empty());

        workoutRepository = mock(WorkoutRepository.class);
        when(workoutRepository.save(any(Workout.class))).thenAnswer(i -> {
            Workout w = i.getArgument(0);
            if (w.getId() == null) w.setId(ids.getAndIncrement());
            if (!workouts.contains(w)) workouts.add(w);
            return w;
        });
        when(workoutRepository.findById(anyLong())).thenAnswer(i -> workouts.stream().filter(w -> w.getId().equals(i.getArgument(0))).findFirst());

        WorkoutAssignmentRepository assignmentRepository = mock(WorkoutAssignmentRepository.class);
        when(assignmentRepository.save(any(WorkoutAssignment.class))).thenAnswer(i -> {
            WorkoutAssignment a = i.getArgument(0);
            if (a.getId() == null) a.setId(ids.getAndIncrement());
            if (!assignments.contains(a)) assignments.add(a);
            return a;
        });
        when(assignmentRepository.findByWorkoutIdAndStudentIdAndStatus(anyLong(), anyLong(), any())).thenAnswer(i ->
                assignments.stream().filter(a -> a.getWorkout().getId().equals(i.getArgument(0))
                        && a.getStudent().getId().equals(i.getArgument(1)) && a.getStatus() == i.getArgument(2)).findFirst());
        when(assignmentRepository.findByStudentIdAndStatus(anyLong(), any())).thenAnswer(i ->
                assignments.stream().filter(a -> a.getStudent().getId().equals(i.getArgument(0)) && a.getStatus() == i.getArgument(1)).toList());

        org.mockito.Mockito.doAnswer(i -> {
            assignments.removeIf(a -> a.getWorkout().getId().equals(i.getArgument(0)));
            return null;
        }).when(assignmentRepository).deleteByWorkoutId(anyLong());

        planRepository = mock(WorkoutExercisesRepository.class);
        when(planRepository.findByWorkoutIdAndRemovedAtIsNullOrderByPositionAscIdAsc(anyLong())).thenReturn(List.of());
        sessions = mock(WorkoutSessionRepository.class);

        WorkoutAccessService access = new WorkoutAccessService(links, students, assignmentRepository, mock(BillingAccessGuard.class));
        service = new WorkoutService(workoutRepository, students, trainers, planRepository, assignmentRepository, access, links, sessions);

        exerciseRepository = mock(ExerciseRepository.class);
        planService = new WorkoutExerciseService(planRepository, workoutRepository, exerciseRepository, access,
                mock(ExercisePerformanceRepository.class));
    }

    @Test
    void createsOwnWorkout_alreadyActiveForThemselves_andListsIt() {
        WorkoutResponse created = service.addWorkout(new CreateWorkoutRequest("Treino A - Superiores", null), ANA);

        assertThat(created.trainerId()).isNull();
        assertThat(workouts.getFirst().getStudentOwner()).isSameAs(ana);
        assertThat(assignments).singleElement().satisfies(a -> {
            assertThat(a.getStudent()).isSameAs(ana);
            assertThat(a.getStatus()).isEqualTo(WorkoutAssignmentStatus.ACTIVE);
        });
        assertThat(service.myWorkouts(ANA)).extracting(WorkoutResponse::name).containsExactly("Treino A - Superiores");
        assertThat(service.getWorkoutById(created.id(), ANA).name()).isEqualTo("Treino A - Superiores");
    }

    @Test
    void studentWithTrainer_cannotCreate() {
        when(links.findByStudentId(anyLong())).thenReturn(Optional.of(
                TrainerStudent.builder().student(ana).status(TrainerStudentStatus.ACTIVE).build()));

        assertThatThrownBy(() -> service.addWorkout(new CreateWorkoutRequest("X", null), ANA))
                .isInstanceOf(AccessDeniedException.class).hasMessageContaining("personal");
        verify(workoutRepository, never()).save(any());
    }

    @Test
    void onlyCatalogExercises_andOnlyTheOwnerEdits() {
        WorkoutResponse created = service.addWorkout(new CreateWorkoutRequest("Treino A", null), ANA);
        TrainerProfile someTrainer = TrainerProfile.builder().id(5L).build();
        when(exerciseRepository.findById(1L)).thenReturn(Optional.of(Exercises.builder().id(1L).name("Supino").build()));
        when(exerciseRepository.findById(2L)).thenReturn(Optional.of(Exercises.builder().id(2L).name("Secreto").trainer(someTrainer).build()));

        assertThat(planService.addWorkoutExercise(new CreateWorkoutExerciseRequest(1L, created.id(), 10, 3, null, 60, null, null), ANA)
                .exerciseName()).isEqualTo("Supino");
        assertThatThrownBy(() -> planService.addWorkoutExercise(
                new CreateWorkoutExerciseRequest(2L, created.id(), 10, 3, null, 60, null, null), ANA))
                .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> planService.addWorkoutExercise(
                new CreateWorkoutExerciseRequest(1L, created.id(), 10, 3, null, 60, null, null), "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void cannotAssignOwnWorkoutToSomeoneElse() {
        WorkoutResponse created = service.addWorkout(new CreateWorkoutRequest("Treino A", null), ANA);
        assertThatThrownBy(() -> service.assignToStudent(created.id(), 99L, ANA)).isInstanceOf(RuntimeException.class);
    }

    @Test
    void delete_unusedIsErased_usedOnlyLeavesTheList() {
        WorkoutResponse unused = service.addWorkout(new CreateWorkoutRequest("Novo", null), ANA);
        when(sessions.existsByAssignmentWorkoutId(unused.id())).thenReturn(false);
        service.deleteById(unused.id(), ANA);
        verify(workoutRepository).deleteById(unused.id());

        WorkoutResponse used = service.addWorkout(new CreateWorkoutRequest("Usado", null), ANA);
        when(sessions.existsByAssignmentWorkoutId(used.id())).thenReturn(true);
        service.deleteById(used.id(), ANA);
        verify(workoutRepository, never()).deleteById(eq(used.id()));
        assertThat(assignments.getLast().getStatus()).isEqualTo(WorkoutAssignmentStatus.ENDED);
        assertThat(service.myWorkouts(ANA)).isEmpty();
    }

    @Test
    void duplicate_staysWithTheStudent_andIsActive() {
        WorkoutResponse created = service.addWorkout(new CreateWorkoutRequest("Treino A", null), ANA);
        WorkoutResponse copy = service.duplicate(created.id(), ANA);

        assertThat(workouts.getLast().getStudentOwner()).isSameAs(ana);
        assertThat(service.myWorkouts(ANA)).extracting(WorkoutResponse::id).contains(copy.id());
    }

    @Test
    void theStudentsTrainer_editsWithOwnExercises_butCannotDeleteNorAssign() {
        WorkoutResponse created = service.addWorkout(new CreateWorkoutRequest("Treino A", null), ANA);
        TrainerProfile joao = TrainerProfile.builder().id(5L)
                .user(User.builder().email("joao@example.com").role(Role.TRAINER).build()).build();
        when(links.findByStudentId(9L)).thenReturn(Optional.of(
                TrainerStudent.builder().trainer(joao).student(ana).status(TrainerStudentStatus.ACTIVE).build()));
        when(exerciseRepository.findById(2L)).thenReturn(Optional.of(Exercises.builder().id(2L).name("Do Joao").trainer(joao).build()));

        assertThat(planService.addWorkoutExercise(new CreateWorkoutExerciseRequest(2L, created.id(), 10, 3, null, 60, null, null),
                "joao@example.com").exerciseName()).isEqualTo("Do Joao");
        assertThatThrownBy(() -> service.deleteById(created.id(), "joao@example.com")).isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> service.assignToStudent(created.id(), 9L, "joao@example.com")).isInstanceOf(RuntimeException.class);
        // outro personal nao edita
        assertThatThrownBy(() -> planService.addWorkoutExercise(
                new CreateWorkoutExerciseRequest(2L, created.id(), 10, 3, null, 60, null, null), "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }
}
