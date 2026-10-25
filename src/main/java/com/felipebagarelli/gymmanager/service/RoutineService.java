package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.dto.RoutineDtos.RoutineItem;
import com.felipebagarelli.gymmanager.dto.RoutineDtos.RoutineResponse;
import com.felipebagarelli.gymmanager.entity.RoutineMode;
import com.felipebagarelli.gymmanager.entity.StudentRoutine;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.StudentRoutineRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Esquema de treino do aluno (F3): dias da semana ou sequencia (AB, ABC...). Na sequencia, o proximo
 * treino e o seguinte ao ultimo concluido, nao importa o dia; "pular" escolhe outro ate a proxima
 * sessao concluida.
 */
@Service
public class RoutineService {

    private final StudentRoutineRepository routineRepository;
    private final WorkoutAssignmentRepository assignmentRepository;
    private final WorkoutRepository workoutRepository;
    private final WorkoutSessionRepository sessionRepository;
    private final StudentProfileRepository studentRepository;
    private final WorkoutAccessService access;

    public RoutineService(StudentRoutineRepository routineRepository, WorkoutAssignmentRepository assignmentRepository,
                          WorkoutRepository workoutRepository, WorkoutSessionRepository sessionRepository,
                          StudentProfileRepository studentRepository, WorkoutAccessService access) {
        this.routineRepository = routineRepository;
        this.assignmentRepository = assignmentRepository;
        this.workoutRepository = workoutRepository;
        this.sessionRepository = sessionRepository;
        this.studentRepository = studentRepository;
        this.access = access;
    }

    public RoutineResponse get(Long studentId, String email) {
        access.assertCanRead(studentId, email);
        return view(studentId);
    }

    /** O personal (vinculo ativo) ou o aluno sem personal, nos treinos que ele montou. */
    @Transactional
    public RoutineResponse set(Long studentId, RoutineMode mode, List<Long> workoutIds, String email) {
        boolean independent = access.isIndependentStudent(studentId, email);
        if (!independent) {
            access.assertCanWrite(studentId, email);
        }
        List<Long> ids = workoutIds == null ? List.of() : List.copyOf(new LinkedHashSet<>(workoutIds));
        if (mode == RoutineMode.ROTATION && ids.size() < 2) {
            throw new BadRequestException("Uma sequência precisa de pelo menos 2 treinos.");
        }
        List<WorkoutAssignment> active = assignmentRepository.findByStudentIdAndStatus(studentId, WorkoutAssignmentStatus.ACTIVE);
        Map<Long, WorkoutAssignment> byWorkout = active.stream()
                .collect(Collectors.toMap(a -> a.getWorkout().getId(), Function.identity(), (a, b) -> a));
        for (Long id : ids) {
            WorkoutAssignment a = byWorkout.get(id);
            if (a == null) {
                throw new BadRequestException("Um dos treinos não está ativo para o aluno.");
            }
            if (independent && a.getWorkout().getStudentOwner() == null) {
                throw new AccessDeniedException("Você só organiza os treinos que montou.");
            }
        }
        if (mode == RoutineMode.ROTATION) {
            for (WorkoutAssignment a : active) {
                int index = ids.indexOf(a.getWorkout().getId());
                a.setRotationOrder(index < 0 ? null : index + 1);
                assignmentRepository.save(a);
            }
        }
        StudentRoutine routine = routineRepository.findById(studentId)
                .orElseGet(() -> StudentRoutine.builder().studentId(studentId).build());
        routine.setMode(mode);
        routine.setNextWorkoutId(null);
        routine.setNextSetAt(null);
        routine.setUpdatedAt(LocalDateTime.now());
        routineRepository.save(routine);
        return view(studentId);
    }

    /** Ao organizar a semana (F2), o aluno volta para o modo dias da semana. */
    @Transactional
    public void useWeekdays(Long studentId) {
        routineRepository.findById(studentId)
                .filter(r -> r.getMode() != RoutineMode.WEEKDAYS)
                .ifPresent(r -> {
                    r.setMode(RoutineMode.WEEKDAYS);
                    r.setNextWorkoutId(null);
                    r.setNextSetAt(null);
                    r.setUpdatedAt(LocalDateTime.now());
                    routineRepository.save(r);
                });
    }

    /** "Pular": o proprio aluno ou o personal dele escolhe o proximo treino da sequencia. */
    @Transactional
    public RoutineResponse skipTo(Long studentId, Long workoutId, String email) {
        if (!access.isStudentThemselves(studentId, email)) {
            access.assertCanWrite(studentId, email);
        }
        StudentRoutine routine = routineRepository.findById(studentId)
                .filter(r -> r.getMode() == RoutineMode.ROTATION)
                .orElseThrow(() -> new ConflictException("O aluno não está treinando por sequência."));
        boolean inSequence = sequence(studentId).stream().anyMatch(a -> a.getWorkout().getId().equals(workoutId));
        if (!inSequence) {
            throw new BadRequestException("Este treino não está na sequência.");
        }
        routine.setNextWorkoutId(workoutId);
        routine.setNextSetAt(LocalDateTime.now());
        routine.setUpdatedAt(LocalDateTime.now());
        routineRepository.save(routine);
        return view(studentId);
    }

    /** A mesma sequencia para varios alunos do personal: atribui os treinos que faltarem. Tudo ou nada. */
    @Transactional
    public List<RoutineResponse> applyToStudents(List<Long> studentIds, List<Long> workoutIds, String email) {
        List<Long> ids = List.copyOf(new LinkedHashSet<>(workoutIds));
        List<Workout> workouts = new ArrayList<>();
        for (Long id : ids) {
            Workout workout = workoutRepository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Treino não encontrado!"));
            if (workout.getTrainer() == null) {
                throw new ConflictException("Treinos montados pelo aluno não podem ir para outros alunos.");
            }
            access.assertOwnsWorkout(workout, email);
            workouts.add(workout);
        }
        List<RoutineResponse> result = new ArrayList<>();
        for (Long studentId : new LinkedHashSet<>(studentIds)) {
            access.assertCanWrite(studentId, email);
            StudentProfile student = studentRepository.findById(studentId)
                    .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
            Set<Long> activeIds = new HashSet<>();
            for (WorkoutAssignment a : assignmentRepository.findByStudentIdAndStatus(studentId, WorkoutAssignmentStatus.ACTIVE)) {
                activeIds.add(a.getWorkout().getId());
            }
            for (Workout w : workouts) {
                if (!activeIds.contains(w.getId())) {
                    assignmentRepository.save(WorkoutAssignment.builder()
                            .workout(w).student(student).status(WorkoutAssignmentStatus.ACTIVE)
                            .startedAt(LocalDateTime.now()).build());
                }
            }
            result.add(set(studentId, RoutineMode.ROTATION, ids, email));
        }
        return result;
    }

    // ---------------------------------------------------------------- calculo

    private List<WorkoutAssignment> sequence(Long studentId) {
        return assignmentRepository.findByStudentIdAndStatus(studentId, WorkoutAssignmentStatus.ACTIVE).stream()
                .filter(a -> a.getRotationOrder() != null)
                .sorted(Comparator.comparing(WorkoutAssignment::getRotationOrder))
                .toList();
    }

    RoutineResponse view(Long studentId) {
        Optional<StudentRoutine> routine = routineRepository.findById(studentId);
        RoutineMode mode = routine.map(StudentRoutine::getMode).orElse(RoutineMode.WEEKDAYS);
        if (mode != RoutineMode.ROTATION) {
            return new RoutineResponse(studentId, mode, List.of(), null);
        }
        List<WorkoutAssignment> seq = sequence(studentId);
        List<RoutineItem> items = new ArrayList<>();
        for (int i = 0; i < seq.size(); i++) {
            items.add(new RoutineItem(seq.get(i).getWorkout().getId(), seq.get(i).getWorkout().getName(), i + 1));
        }
        return new RoutineResponse(studentId, mode, items, next(seq, routine.get(), studentId));
    }

    private Long next(List<WorkoutAssignment> seq, StudentRoutine routine, Long studentId) {
        if (seq.isEmpty()) return null;
        List<Long> ids = seq.stream().map(a -> a.getWorkout().getId()).toList();
        // ultima sessao concluida de um treino da sequencia
        Optional<WorkoutSession> last = sessionRepository.findByAssignmentStudentIdOrderByStartedAtDesc(studentId).stream()
                .filter(s -> s.getFinishedAt() != null && ids.contains(s.getAssignment().getWorkout().getId()))
                .findFirst();
        Long chosen = routine.getNextWorkoutId();
        if (chosen != null && ids.contains(chosen)
                && (last.isEmpty() || routine.getNextSetAt().isAfter(last.get().getFinishedAt()))) {
            return chosen;
        }
        if (last.isEmpty()) return ids.getFirst();
        int index = ids.indexOf(last.get().getAssignment().getWorkout().getId());
        return ids.get((index + 1) % ids.size());
    }
}
