package com.felipebagarelli.gymmanager.session.service;

import com.felipebagarelli.gymmanager.billing.service.BillingAccessGuard;
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
import com.felipebagarelli.gymmanager.session.dto.WorkoutSessionResponse;
import com.felipebagarelli.gymmanager.session.entity.ExercisePerformance;
import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class WorkoutSessionService {

    private final WorkoutSessionRepository sessionRepository;
    private final ExercisePerformanceRepository performanceRepository;
    private final WorkoutAssignmentRepository assignmentRepository;
    private final WorkoutExercisesRepository workoutExercisesRepository;
    private final WorkoutAccessService workoutAccessService;
    private final BillingAccessGuard billingAccessGuard;

    public WorkoutSessionService(WorkoutSessionRepository sessionRepository,
                                 ExercisePerformanceRepository performanceRepository,
                                 WorkoutAssignmentRepository assignmentRepository,
                                 WorkoutExercisesRepository workoutExercisesRepository,
                                 WorkoutAccessService workoutAccessService,
                                 BillingAccessGuard billingAccessGuard) {
        this.billingAccessGuard = billingAccessGuard;
        this.sessionRepository = sessionRepository;
        this.performanceRepository = performanceRepository;
        this.assignmentRepository = assignmentRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
        this.workoutAccessService = workoutAccessService;
    }

    private PerformanceResponse toResponse(ExercisePerformance p) {
        return new PerformanceResponse(p.getId(), p.getWorkoutExercise().getId(), p.getSetNumber(), p.getReps(), p.getLoadKg(), p.getEffort());
    }

    private WorkoutSessionResponse toResponse(WorkoutSession s) {
        List<PerformanceResponse> performances = performanceRepository.findBySessionIdOrderByIdAsc(s.getId()).stream()
                .map(this::toResponse)
                .toList();
        return new WorkoutSessionResponse(s.getId(), s.getAssignment().getWorkout().getId(),
                s.getAssignment().getStudent().getId(), s.getStartedAt(), s.getFinishedAt(), performances);
    }

    private WorkoutSession findSession(Long id) {
        return sessionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Sessão não encontrada!"));
    }

    private void assertStudentOwns(WorkoutSession session, String email) {
        if (!session.getAssignment().getStudent().getUser().getEmail().equalsIgnoreCase(email)) {
            throw new AccessDeniedException("Você não tem permissão para alterar esta sessão.");
        }
    }

    private void assertOpen(WorkoutSession session) {
        if (session.getFinishedAt() != null) {
            throw new ConflictException("Esta sessão já foi finalizada.");
        }
    }

    private ExercisePerformance findPerformance(WorkoutSession session, Long performanceId) {
        ExercisePerformance performance = performanceRepository.findById(performanceId)
                .orElseThrow(() -> new ResourceNotFoundException("Registro de série não encontrado!"));
        if (!performance.getSession().getId().equals(session.getId())) {
            throw new ResourceNotFoundException("Registro de série não encontrado!");
        }
        return performance;
    }

    @Transactional
    public WorkoutSessionResponse start(Long workoutId, String authenticatedEmail) {
        billingAccessGuard.assertStudentNotBlockedByEmail(authenticatedEmail);
        WorkoutAssignment assignment = assignmentRepository
                .findByWorkoutIdAndStudentUserEmailAndStatus(workoutId, authenticatedEmail, WorkoutAssignmentStatus.ACTIVE)
                .orElseThrow(() -> new AccessDeniedException("Este treino não está atribuído e ativo para você."));

        if (sessionRepository.existsByAssignmentIdAndFinishedAtIsNull(assignment.getId())) {
            throw new ConflictException("Já existe uma sessão em andamento para este treino.");
        }

        WorkoutSession session = sessionRepository.save(WorkoutSession.builder()
                .assignment(assignment)
                .startedAt(LocalDateTime.now())
                .build());
        return toResponse(session);
    }

    @Transactional
    public PerformanceResponse addPerformance(Long sessionId, RecordPerformanceRequest request, String authenticatedEmail) {
        WorkoutSession session = findSession(sessionId);
        assertStudentOwns(session, authenticatedEmail);
        assertOpen(session);

        WorkoutExercises workoutExercise = workoutExercisesRepository.findById(request.workoutExerciseId())
                .orElseThrow(() -> new ResourceNotFoundException("Exercício não encontrado!"));
        if (!workoutExercise.getWorkout().getId().equals(session.getAssignment().getWorkout().getId())) {
            throw new ResourceNotFoundException("Este exercício não pertence ao treino da sessão.");
        }

        ExercisePerformance performance = performanceRepository.save(ExercisePerformance.builder()
                .session(session)
                .workoutExercise(workoutExercise)
                .setNumber(request.setNumber())
                .reps(request.reps())
                .loadKg(request.loadKg())
                .effort(request.effort())
                .build());
        return toResponse(performance);
    }

    @Transactional
    public PerformanceResponse updatePerformance(Long sessionId, Long performanceId, UpdatePerformanceRequest request, String authenticatedEmail) {
        WorkoutSession session = findSession(sessionId);
        assertStudentOwns(session, authenticatedEmail);
        assertOpen(session);

        ExercisePerformance performance = findPerformance(session, performanceId);
        performance.setSetNumber(request.setNumber());
        performance.setReps(request.reps());
        performance.setLoadKg(request.loadKg());
        performance.setEffort(request.effort());
        return toResponse(performanceRepository.save(performance));
    }

    @Transactional
    public void deletePerformance(Long sessionId, Long performanceId, String authenticatedEmail) {
        WorkoutSession session = findSession(sessionId);
        assertStudentOwns(session, authenticatedEmail);
        assertOpen(session);
        performanceRepository.delete(findPerformance(session, performanceId));
    }

    @Transactional
    public WorkoutSessionResponse finish(Long sessionId, String authenticatedEmail) {
        WorkoutSession session = findSession(sessionId);
        assertStudentOwns(session, authenticatedEmail);
        assertOpen(session);
        session.setFinishedAt(LocalDateTime.now());
        return toResponse(sessionRepository.save(session));
    }

    public WorkoutSessionResponse getById(Long sessionId, String authenticatedEmail) {
        WorkoutSession session = findSession(sessionId);
        workoutAccessService.assertCanRead(session.getAssignment().getStudent().getId(), authenticatedEmail);
        return toResponse(session);
    }

    public List<WorkoutSessionResponse> listByStudent(Long studentId, String authenticatedEmail) {
        workoutAccessService.assertCanRead(studentId, authenticatedEmail);
        return sessionRepository.findByAssignmentStudentIdOrderByStartedAtDesc(studentId).stream()
                .map(this::toResponse)
                .toList();
    }
}
