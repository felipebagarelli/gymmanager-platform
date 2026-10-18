package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.ai.provider.AiProvider;
import com.felipebagarelli.gymmanager.ai.provider.AiReply;
import com.felipebagarelli.gymmanager.ai.provider.AiRequest;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposalResponse;
import com.felipebagarelli.gymmanager.aiworkout.entity.AiWorkoutProposal;
import com.felipebagarelli.gymmanager.aiworkout.entity.ProposalKind;
import com.felipebagarelli.gymmanager.aiworkout.repository.AiWorkoutProposalRepository;
import com.felipebagarelli.gymmanager.entity.ExerciseEquipment;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingGoal;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLevel;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLocation;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import com.felipebagarelli.gymmanager.onboarding.repository.TrainingProfileRepository;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.session.entity.Effort;
import com.felipebagarelli.gymmanager.session.entity.ExercisePerformance;
import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class WorkoutAdjustmentServiceTest {

    private static final String ANA = "ana@example.com";

    private final StudentProfile ana = StudentProfile.builder().id(9L).build();
    private final Workout own = Workout.builder().id(10L).name("Treino A").studentOwner(ana).build();
    private final Exercises goblet = Exercises.builder().id(1L).catalogCode("agachamento_goblet").name("Agachamento goblet")
            .muscleGroup("Pernas").equipment(ExerciseEquipment.DUMBBELL).build();
    private final WorkoutExercises item = WorkoutExercises.builder().id(100L).workout(own).exercise(goblet)
            .sets(3).reps(12).restSeconds(60).targetLoad(20.0).position(1).build();

    private AiProvider ai;
    private WorkoutSessionRepository sessions;
    private ExercisePerformanceRepository performances;
    private AiWorkoutProposalRepository repo;
    private WorkoutAdjustmentService service;

    private WorkoutSession session(long id, int daysAgo) {
        WorkoutAssignment assignment = WorkoutAssignment.builder().workout(own).student(ana).build();
        return WorkoutSession.builder().id(id).assignment(assignment)
                .startedAt(LocalDateTime.now().minusDays(daysAgo)).finishedAt(LocalDateTime.now().minusDays(daysAgo).plusHours(1)).build();
    }

    private ExercisePerformance set(long sessionId, int reps, double load, Effort effort) {
        return ExercisePerformance.builder().workoutExercise(item).reps(reps).loadKg(load).effort(effort).build();
    }

    @BeforeEach
    void setUp() {
        AiWorkoutProposalService proposals = mock(AiWorkoutProposalService.class);
        when(proposals.requireAllowed(ANA)).thenReturn(ana);
        when(proposals.toResponse(any())).thenAnswer(i -> {
            AiWorkoutProposal p = i.getArgument(0);
            return new ProposalResponse(p.getId(), p.getStatus(), null, p.getCreatedAt(), List.of(), p.getKind().name(),
                    AdjustmentParser.fromJson(p.getProposalJson()));
        });
        WorkoutRepository workouts = mock(WorkoutRepository.class);
        when(workouts.findById(10L)).thenReturn(Optional.of(own));
        when(workouts.findById(11L)).thenReturn(Optional.of(Workout.builder().id(11L).studentOwner(StudentProfile.builder().id(77L).build()).build()));
        WorkoutAssignmentRepository assignments = mock(WorkoutAssignmentRepository.class);
        when(assignments.findByWorkoutIdAndStudentIdAndStatus(eq(10L), eq(9L), eq(WorkoutAssignmentStatus.ACTIVE)))
                .thenReturn(Optional.of(WorkoutAssignment.builder().workout(own).student(ana).build()));
        WorkoutExercisesRepository plan = mock(WorkoutExercisesRepository.class);
        when(plan.findByWorkoutIdAndRemovedAtIsNullOrderByPositionAscIdAsc(10L)).thenReturn(List.of(item));
        sessions = mock(WorkoutSessionRepository.class);
        performances = mock(ExercisePerformanceRepository.class);
        TrainingProfileRepository profiles = mock(TrainingProfileRepository.class);
        when(profiles.findByStudentId(anyLong())).thenReturn(Optional.of(TrainingProfile.builder().goal(TrainingGoal.STRENGTH)
                .level(TrainingLevel.INTERMEDIATE).daysPerWeek(3).minutesPerSession(60).location(TrainingLocation.GYM).build()));
        ExerciseRepository exercises = mock(ExerciseRepository.class);
        when(exercises.findByTrainerIsNullOrderByNameAsc()).thenReturn(List.of(goblet));
        repo = mock(AiWorkoutProposalRepository.class);
        when(repo.save(any(AiWorkoutProposal.class))).thenAnswer(i -> {
            AiWorkoutProposal p = i.getArgument(0);
            p.setId(55L);
            return p;
        });
        ai = mock(AiProvider.class);
        when(ai.ask(any())).thenReturn(new AiReply("""
                {"summary": "Progrida no goblet.", "changes": [
                  {"workoutExerciseId": 100, "action": "PROGRESS", "sets": 3, "reps": 12, "restSeconds": 60, "targetLoad": 21.5}
                ]}""", 900, 200));
        service = new WorkoutAdjustmentService(proposals, ai, repo, workouts, assignments, plan, sessions, performances, profiles, exercises);
    }

    @Test
    void history_usesTheLastSessionOfThisWorkout() {
        when(sessions.findByAssignmentStudentIdOrderByStartedAtDesc(9L)).thenReturn(List.of(session(2, 1), session(1, 4)));
        when(performances.findBySessionIdOrderByIdAsc(2L)).thenReturn(List.of(set(2, 12, 20, Effort.IDEAL), set(2, 10, 20, Effort.EASY)));
        when(performances.findBySessionIdOrderByIdAsc(1L)).thenReturn(List.of(set(1, 12, 17.5, Effort.EASY)));

        Map<Long, ExerciseHistory> history = service.history(ana, 10L, List.of(item));

        ExerciseHistory h = history.get(100L);
        assertThat(h.sessionsDone()).isEqualTo(2);
        assertThat(h.lastMaxLoad()).isEqualTo(20.0);
        assertThat(h.lastBestReps()).isEqualTo(12);
        assertThat(h.lastEffort()).isEqualTo(Effort.EASY);
        assertThat(h.canIncreaseLoad()).isTrue();
    }

    @Test
    void propose_sendsThePlanAndHistory_andStoresAnAdjustment() {
        when(sessions.findByAssignmentStudentIdOrderByStartedAtDesc(9L)).thenReturn(List.of(session(2, 1), session(1, 4)));
        when(performances.findBySessionIdOrderByIdAsc(anyLong())).thenReturn(List.of(set(2, 12, 20, Effort.EASY)));

        ProposalResponse response = service.propose(ANA, 10L, "quero progredir");

        ArgumentCaptor<AiRequest> request = ArgumentCaptor.forClass(AiRequest.class);
        verify(ai).ask(request.capture());
        assertThat(request.getValue().systemPrompt()).contains("100 | Agachamento goblet", "2 sessões", "20.0kg");
        assertThat(response.kind()).isEqualTo(ProposalKind.ADJUSTMENT.name());
        assertThat(response.adjustment().changes().getFirst().loadAfter()).isEqualTo(21.5);
        ArgumentCaptor<AiWorkoutProposal> saved = ArgumentCaptor.forClass(AiWorkoutProposal.class);
        verify(repo).save(saved.capture());
        assertThat(saved.getValue().getTargetWorkoutId()).isEqualTo(10L);
    }

    @Test
    void needsAtLeastOneSession_andOnlyOwnWorkouts() {
        when(sessions.findByAssignmentStudentIdOrderByStartedAtDesc(9L)).thenReturn(List.of());
        assertThatThrownBy(() -> service.propose(ANA, 10L, null)).isInstanceOf(ConflictException.class)
                .hasMessageContaining("pelo menos uma vez");
        assertThatThrownBy(() -> service.propose(ANA, 11L, null)).isInstanceOf(ResourceNotFoundException.class);
        verify(ai, never()).ask(any());
    }
}
