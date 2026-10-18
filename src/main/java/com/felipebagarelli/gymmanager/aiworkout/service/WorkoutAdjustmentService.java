package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.ai.provider.AiProvider;
import com.felipebagarelli.gymmanager.ai.provider.AiReply;
import com.felipebagarelli.gymmanager.ai.provider.AiRequest;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.AdjustmentContent;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposalResponse;
import com.felipebagarelli.gymmanager.aiworkout.entity.AiWorkoutProposal;
import com.felipebagarelli.gymmanager.aiworkout.entity.ProposalKind;
import com.felipebagarelli.gymmanager.aiworkout.entity.ProposalStatus;
import com.felipebagarelli.gymmanager.aiworkout.repository.AiWorkoutProposalRepository;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import com.felipebagarelli.gymmanager.onboarding.repository.TrainingProfileRepository;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.session.entity.ExercisePerformance;
import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** D4: a IA sugere ajustes num treino do proprio aluno, com base nas ultimas sessoes dele. */
@Service
public class WorkoutAdjustmentService {

    static final int HISTORY_SESSIONS = 4;

    private final AiWorkoutProposalService proposals;
    private final AiProvider aiProvider;
    private final AiWorkoutProposalRepository repository;
    private final WorkoutRepository workoutRepository;
    private final WorkoutAssignmentRepository assignmentRepository;
    private final WorkoutExercisesRepository planRepository;
    private final WorkoutSessionRepository sessionRepository;
    private final ExercisePerformanceRepository performanceRepository;
    private final TrainingProfileRepository trainingProfileRepository;
    private final ExerciseRepository exerciseRepository;

    public WorkoutAdjustmentService(AiWorkoutProposalService proposals, AiProvider aiProvider,
                                    AiWorkoutProposalRepository repository, WorkoutRepository workoutRepository,
                                    WorkoutAssignmentRepository assignmentRepository, WorkoutExercisesRepository planRepository,
                                    WorkoutSessionRepository sessionRepository, ExercisePerformanceRepository performanceRepository,
                                    TrainingProfileRepository trainingProfileRepository, ExerciseRepository exerciseRepository) {
        this.proposals = proposals;
        this.aiProvider = aiProvider;
        this.repository = repository;
        this.workoutRepository = workoutRepository;
        this.assignmentRepository = assignmentRepository;
        this.planRepository = planRepository;
        this.sessionRepository = sessionRepository;
        this.performanceRepository = performanceRepository;
        this.trainingProfileRepository = trainingProfileRepository;
        this.exerciseRepository = exerciseRepository;
    }

    /** Pede os ajustes a IA (fora de transacao); so grava e conta se vier ao menos um ajuste valido. */
    public ProposalResponse propose(String email, Long workoutId, String note) {
        StudentProfile student = proposals.requireAllowed(email);
        Workout workout = workoutRepository.findById(workoutId)
                .filter(w -> w.getStudentOwner() != null && w.getStudentOwner().getId().equals(student.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Treino não encontrado!"));
        assignmentRepository.findByWorkoutIdAndStudentIdAndStatus(workoutId, student.getId(), WorkoutAssignmentStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Treino não encontrado!"));

        List<WorkoutExercises> plan = planRepository.findByWorkoutIdAndRemovedAtIsNullOrderByPositionAscIdAsc(workoutId);
        Map<Long, ExerciseHistory> history = history(student, workoutId, plan);
        if (history.values().stream().noneMatch(h -> h.sessionsDone() > 0)) {
            throw new ConflictException("Faça este treino pelo menos uma vez para a IA sugerir ajustes.");
        }
        TrainingProfile profile = trainingProfileRepository.findByStudentId(student.getId()).orElseThrow();
        ProposalRules rules = ProposalRules.of(profile);
        Map<String, Exercises> catalog = new LinkedHashMap<>();
        for (Exercises e : exerciseRepository.findByTrainerIsNullOrderByNameAsc()) {
            if (e.getCatalogCode() != null && e.getEquipment() != null && rules.equipment().contains(e.getEquipment())) {
                catalog.put(e.getCatalogCode(), e);
            }
        }
        String cleanNote = note == null ? null : ProposalParser.clean(note, 300);

        AiReply reply = aiProvider.ask(new AiRequest(AdjustmentPromptBuilder.system(profile, rules, plan, history, catalog.values()),
                List.of(), AdjustmentPromptBuilder.question(cleanNote), null, AiWorkoutProposalService.MAX_TOKENS));
        AdjustmentContent content = AdjustmentParser.parse(reply.text(), workout, plan, history, catalog, rules);

        AiWorkoutProposal saved = repository.save(AiWorkoutProposal.builder()
                .student(student)
                .status(ProposalStatus.PROPOSED)
                .kind(ProposalKind.ADJUSTMENT)
                .targetWorkoutId(workoutId)
                .requestNote(cleanNote == null || cleanNote.isEmpty() ? null : cleanNote)
                .proposalJson(AdjustmentParser.toJson(content))
                .inputTokens(reply.inputTokens())
                .outputTokens(reply.outputTokens())
                .createdAt(LocalDateTime.now())
                .build());
        return proposals.toResponse(saved);
    }

    /** O que o aluno fez em cada exercicio do plano nas ultimas sessoes finalizadas deste treino. */
    Map<Long, ExerciseHistory> history(StudentProfile student, Long workoutId, List<WorkoutExercises> plan) {
        List<WorkoutSession> sessions = sessionRepository.findByAssignmentStudentIdOrderByStartedAtDesc(student.getId()).stream()
                .filter(s -> s.getFinishedAt() != null && s.getAssignment().getWorkout().getId().equals(workoutId))
                .limit(HISTORY_SESSIONS)
                .toList();
        Map<Long, List<List<ExercisePerformance>>> perItem = new HashMap<>();
        for (WorkoutSession session : sessions) { // mais recente primeiro
            Map<Long, List<ExercisePerformance>> bySession = new HashMap<>();
            for (ExercisePerformance p : performanceRepository.findBySessionIdOrderByIdAsc(session.getId())) {
                bySession.computeIfAbsent(p.getWorkoutExercise().getId(), k -> new ArrayList<>()).add(p);
            }
            bySession.forEach((id, sets) -> perItem.computeIfAbsent(id, k -> new ArrayList<>()).add(sets));
        }
        Map<Long, ExerciseHistory> out = new HashMap<>();
        for (WorkoutExercises item : plan) {
            List<List<ExercisePerformance>> done = perItem.getOrDefault(item.getId(), List.of());
            if (done.isEmpty()) {
                out.put(item.getId(), new ExerciseHistory(item.getId(), 0, null, 0, null));
                continue;
            }
            List<ExercisePerformance> last = done.getFirst();
            Double maxLoad = last.stream().map(ExercisePerformance::getLoadKg).filter(java.util.Objects::nonNull)
                    .max(Double::compare).orElse(null);
            int bestReps = last.stream().mapToInt(ExercisePerformance::getReps).max().orElse(0);
            var effort = last.stream().map(ExercisePerformance::getEffort).filter(java.util.Objects::nonNull)
                    .reduce((a, b) -> b).orElse(null);
            out.put(item.getId(), new ExerciseHistory(item.getId(), done.size(), maxLoad, bestReps, effort));
        }
        return out;
    }
}
