package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutExercisesResponse;
import com.felipebagarelli.gymmanager.dto.response.WorkoutResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Montagem do treino: plano (adicionar, retirar, reordenar) e duplicar. */
@ExtendWith(MockitoExtension.class)
class WorkoutPlanServiceTest {

    private static final String OWNER = "joao@example.com";

    @Mock private WorkoutExercisesRepository workoutExercisesRepository;
    @Mock private WorkoutRepository workoutRepository;
    @Mock private ExerciseRepository exerciseRepository;
    @Mock private WorkoutAccessService accessService;
    @Mock private ExercisePerformanceRepository performanceRepository;
    @Mock private WorkoutAssignmentRepository assignmentRepository;
    @Mock private StudentProfileRepository studentProfileRepository;
    @Mock private TrainerProfileRepository trainerProfileRepository;

    private WorkoutExerciseService planService;
    private WorkoutService workoutService;

    private TrainerProfile trainer;
    private Workout workout;
    private Exercises supino;
    private WorkoutExercises first;
    private WorkoutExercises second;

    @BeforeEach
    void setUp() {
        planService = new WorkoutExerciseService(workoutExercisesRepository, workoutRepository, exerciseRepository,
                accessService, performanceRepository);
        workoutService = new WorkoutService(workoutRepository, studentProfileRepository, trainerProfileRepository,
                workoutExercisesRepository, assignmentRepository, accessService,
                org.mockito.Mockito.mock(com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository.class),
                org.mockito.Mockito.mock(com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository.class));

        trainer = TrainerProfile.builder().id(1L)
                .user(User.builder().email(OWNER).role(Role.TRAINER).build()).build();
        workout = Workout.builder().id(10L).name("Treino A").trainer(trainer).build();
        supino = Exercises.builder().id(1L).name("Supino").muscleGroup("Peito").build();
        Exercises remada = Exercises.builder().id(2L).name("Remada").muscleGroup("Costas").build();
        first = WorkoutExercises.builder().id(100L).workout(workout).exercise(supino).sets(3).reps(10).position(1).build();
        second = WorkoutExercises.builder().id(101L).workout(workout).exercise(remada).sets(4).reps(8).position(2)
                .restSeconds(90).targetLoad(40.0).notes("pegada neutra").build();

        lenient().when(workoutRepository.findById(10L)).thenReturn(Optional.of(workout));
        lenient().when(exerciseRepository.findById(1L)).thenReturn(Optional.of(supino));
        lenient().when(workoutExercisesRepository.findByWorkoutIdAndRemovedAtIsNullOrderByPositionAscIdAsc(10L))
                .thenReturn(List.of(first, second));
        lenient().when(workoutRepository.save(any())).thenAnswer(inv -> {
            Workout w = inv.getArgument(0);
            if (w.getId() == null) w.setId(11L);
            return w;
        });
    }

    @Test
    void add_withoutPosition_goesToTheEnd_andReturnsTheExerciseName() {
        WorkoutExercisesResponse added = planService.addWorkoutExercise(
                new CreateWorkoutExerciseRequest(1L, 10L, 12, 3, null, 60, null, null), OWNER);

        assertThat(added.position()).isEqualTo(3);
        assertThat(added.exerciseName()).isEqualTo("Supino");
        assertThat(added.muscleGroup()).isEqualTo("Peito");
    }

    @Test
    void add_rejectsAnotherTrainersExercise() {
        TrainerProfile other = TrainerProfile.builder().id(9L).build();
        when(exerciseRepository.findById(3L))
                .thenReturn(Optional.of(Exercises.builder().id(3L).name("X").trainer(other).build()));

        assertThatThrownBy(() -> planService.addWorkoutExercise(
                new CreateWorkoutExerciseRequest(3L, 10L, 12, 3, null, null, null, null), OWNER))
                .isInstanceOf(AccessDeniedException.class);
        verify(workoutExercisesRepository, never()).save(any());
    }

    @Test
    void remove_withRecordedSets_keepsHistoryAndHidesFromPlan() {
        when(workoutExercisesRepository.findById(100L)).thenReturn(Optional.of(first));
        when(performanceRepository.existsByWorkoutExerciseId(100L)).thenReturn(true);

        planService.deleteById(100L, OWNER);

        assertThat(first.getRemovedAt()).isNotNull();
        verify(workoutExercisesRepository).save(first);
        verify(workoutExercisesRepository, never()).delete(any());
    }

    @Test
    void remove_withoutHistory_deletes() {
        when(workoutExercisesRepository.findById(100L)).thenReturn(Optional.of(first));
        when(performanceRepository.existsByWorkoutExerciseId(100L)).thenReturn(false);

        planService.deleteById(100L, OWNER);

        verify(workoutExercisesRepository).delete(first);
    }

    @Test
    void remove_onlyTheOwner() {
        when(workoutExercisesRepository.findById(100L)).thenReturn(Optional.of(first));
        doThrow(new AccessDeniedException("x")).when(accessService).assertOwnsWorkout(workout, "outro@example.com");

        assertThatThrownBy(() -> planService.deleteById(100L, "outro@example.com")).isInstanceOf(AccessDeniedException.class);
        verify(workoutExercisesRepository, never()).delete(any());
    }

    @Test
    void reorder_setsPositionsInTheGivenOrder() {
        planService.reorder(10L, List.of(101L, 100L), OWNER);

        assertThat(second.getPosition()).isEqualTo(1);
        assertThat(first.getPosition()).isEqualTo(2);
    }

    @Test
    void reorder_mustListEveryExerciseOnce() {
        assertThatThrownBy(() -> planService.reorder(10L, List.of(101L), OWNER)).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> planService.reorder(10L, List.of(101L, 101L), OWNER)).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> planService.reorder(10L, List.of(101L, 999L), OWNER)).isInstanceOf(BadRequestException.class);
        assertThat(first.getPosition()).isEqualTo(1);
    }

    @Test
    void duplicate_copiesNameAndPlanButNotAssignments() {
        when(workoutExercisesRepository.countByWorkoutIdAndRemovedAtIsNull(11L)).thenReturn(2L);
        when(assignmentRepository.countByWorkoutIdAndStatus(11L, WorkoutAssignmentStatus.ACTIVE)).thenReturn(0L);

        WorkoutResponse copy = workoutService.duplicate(10L, OWNER);

        assertThat(copy.id()).isEqualTo(11L);
        assertThat(copy.name()).isEqualTo("Treino A (cópia)");
        assertThat(copy.exerciseCount()).isEqualTo(2);
        assertThat(copy.studentCount()).isZero();

        ArgumentCaptor<WorkoutExercises> items = ArgumentCaptor.forClass(WorkoutExercises.class);
        verify(workoutExercisesRepository, times(2)).save(items.capture());
        List<WorkoutExercises> copied = new ArrayList<>(items.getAllValues());
        assertThat(copied).allMatch(item -> item.getWorkout().getId().equals(11L));
        assertThat(copied.get(1).getNotes()).isEqualTo("pegada neutra");
        assertThat(copied.get(1).getTargetLoad()).isEqualTo(40.0);
        assertThat(copied).extracting(WorkoutExercises::getPosition).containsExactly(1, 2);
        verify(assignmentRepository, never()).save(any());
    }

    @Test
    void activeAssignments_onlyTheOwner() {
        doThrow(new AccessDeniedException("x")).when(accessService).assertOwnsWorkout(workout, "aluno@example.com");

        assertThatThrownBy(() -> workoutService.activeAssignments(10L, "aluno@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }
}
