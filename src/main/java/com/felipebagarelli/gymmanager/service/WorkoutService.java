package com.felipebagarelli.gymmanager.service;


import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutAssignmentResponse;
import com.felipebagarelli.gymmanager.dto.response.WorkoutResponse;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

@Service
public class WorkoutService {

    private final WorkoutRepository workoutRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final WorkoutExercisesRepository workoutExercisesRepository;
    private final WorkoutAssignmentRepository workoutAssignmentRepository;
    private final WorkoutAccessService workoutAccessService;
    private final TrainerStudentRepository trainerStudentRepository;
    private final WorkoutSessionRepository sessionRepository;

    public WorkoutService(WorkoutRepository workoutRepository,
                          StudentProfileRepository studentProfileRepository,
                          TrainerProfileRepository trainerProfileRepository,
                          WorkoutExercisesRepository workoutExercisesRepository,
                          WorkoutAssignmentRepository workoutAssignmentRepository,
                          WorkoutAccessService workoutAccessService,
                          TrainerStudentRepository trainerStudentRepository,
                          WorkoutSessionRepository sessionRepository){
        this.trainerStudentRepository = trainerStudentRepository;
        this.sessionRepository = sessionRepository;
        this.workoutRepository = workoutRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
        this.workoutAssignmentRepository = workoutAssignmentRepository;
        this.workoutAccessService = workoutAccessService;
    }

    private static final int MAX_NAME_LENGTH = 255;

    /** Visao do aluno (ou de quem nao e dono): sem o numero de alunos do personal. */
    public WorkoutResponse toResponse(Workout workout){
        Long trainerId = workout.getTrainer() != null ? workout.getTrainer().getId() : null;
        int exercises = (int) workoutExercisesRepository.countByWorkoutIdAndRemovedAtIsNull(workout.getId());
        return new WorkoutResponse(workout.getId(), workout.getName(), trainerId, exercises, null);
    }

    /** Visao do personal dono: inclui quantos alunos estao com o treino ativo. */
    private WorkoutResponse toOwnerResponse(Workout workout){
        WorkoutResponse base = toResponse(workout);
        int students = (int) workoutAssignmentRepository.countByWorkoutIdAndStatus(workout.getId(), WorkoutAssignmentStatus.ACTIVE);
        return new WorkoutResponse(base.id(), base.name(), base.trainerId(), base.exerciseCount(), students);
    }

    private WorkoutAssignmentResponse toResponse(WorkoutAssignment a){
        return new WorkoutAssignmentResponse(a.getId(), a.getWorkout().getId(), a.getStudent().getId(),
                a.getStatus(), a.getStartedAt(), a.getEndedAt(), a.getStudent().getName());
    }

    private Workout findWorkout(Long id){
        return workoutRepository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Treino não encontrado!"));
    }

    private StudentProfile findStudent(Long id){
        return studentProfileRepository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
    }

    private WorkoutAssignmentResponse assign(Workout workout, StudentProfile student){
        if (workoutAssignmentRepository.findByWorkoutIdAndStudentIdAndStatus(
                workout.getId(), student.getId(), WorkoutAssignmentStatus.ACTIVE).isPresent()) {
            throw new ConflictException("Este treino já está ativo para o aluno.");
        }
        WorkoutAssignment assignment = WorkoutAssignment.builder()
                .workout(workout)
                .student(student)
                .status(WorkoutAssignmentStatus.ACTIVE)
                .startedAt(LocalDateTime.now())
                .build();
        return toResponse(workoutAssignmentRepository.save(assignment));
    }

    /** Aluno sem personal (sem vinculo ativo ou pausado): monta os proprios treinos. */
    private StudentProfile independentStudent(String email) {
        StudentProfile student = studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
        boolean withTrainer = trainerStudentRepository.findByStudentId(student.getId())
                .map(l -> l.getStatus() == TrainerStudentStatus.ACTIVE || l.getStatus() == TrainerStudentStatus.PAUSED)
                .orElse(false);
        if (withTrainer) {
            throw new AccessDeniedException("Seu personal monta os seus treinos.");
        }
        return student;
    }

    @Transactional
    public WorkoutResponse addWorkout(CreateWorkoutRequest request, String authenticatedEmail){
        Optional<TrainerProfile> trainerProfile = trainerProfileRepository.findByUserEmail(authenticatedEmail);
        if (trainerProfile.isEmpty()) {
            // aluno sem personal: o treino e dele e ja fica ativo para ele
            StudentProfile owner = independentStudent(authenticatedEmail);
            Workout own = workoutRepository.save(Workout.builder()
                    .name(request.name().trim())
                    .studentOwner(owner)
                    .build());
            assign(own, owner);
            return toResponse(own);
        }
        TrainerProfile trainer = trainerProfile.get();

        StudentProfile student = null;
        if (request.studentId() != null) {
            student = findStudent(request.studentId());
            workoutAccessService.assertCanWrite(student.getId(), authenticatedEmail);
        }

        Workout workout = workoutRepository.save(Workout.builder()
                .name(request.name().trim())
                .trainer(trainer)
                .build());

        if (student != null) {
            assign(workout, student);
        }
        return toOwnerResponse(workout);
    }

    public List<WorkoutResponse> myWorkouts(String authenticatedEmail){
        Optional<TrainerProfile> trainerProfile = trainerProfileRepository.findByUserEmail(authenticatedEmail);
        if (trainerProfile.isEmpty()) {
            // aluno sem personal: os treinos dele que estao em uso
            StudentProfile owner = independentStudent(authenticatedEmail);
            return workoutAssignmentRepository.findByStudentIdAndStatus(owner.getId(), WorkoutAssignmentStatus.ACTIVE).stream()
                    .map(WorkoutAssignment::getWorkout)
                    .filter(w -> w.getStudentOwner() != null && w.getStudentOwner().getId().equals(owner.getId()))
                    .map(this::toResponse)
                    .sorted(Comparator.comparing(WorkoutResponse::name, String.CASE_INSENSITIVE_ORDER))
                    .toList();
        }
        TrainerProfile trainer = trainerProfile.get();
        return workoutRepository.findByTrainerId(trainer.getId()).stream()
                .map(this::toOwnerResponse)
                .sorted(Comparator.comparing(WorkoutResponse::name, String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    public List<WorkoutResponse> allWorkout (Long studentId, String authenticatedEmail){
        workoutAccessService.assertCanRead(studentId, authenticatedEmail);
        return workoutAssignmentRepository.findByStudentIdAndStatus(studentId, WorkoutAssignmentStatus.ACTIVE).stream()
                .map(a -> toResponse(a.getWorkout()))
                .toList();
    }

    @Transactional
    public void deleteById (Long id, String authenticatedEmail){
        Workout workout = findWorkout(id);
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        if (workout.getStudentOwner() != null) {
            // o personal edita, mas so o aluno exclui o treino que montou
            if (!workoutAccessService.isStudentOwner(workout, authenticatedEmail)) {
                throw new AccessDeniedException("Só o aluno pode excluir um treino que ele montou.");
            }
            deleteOwnWorkout(workout);
            return;
        }
        if (workoutAssignmentRepository.existsByWorkoutId(id)) {
            throw new ConflictException("Este treino já foi atribuído a alunos; encerre as atribuições em vez de excluí-lo.");
        }
        workoutExercisesRepository.deleteByWorkoutId(id);
        workoutRepository.deleteById(id);
    }

    /**
     * Treino do proprio aluno: se ja treinou com ele, so sai da lista (o historico continua);
     * se nunca usou, e apagado.
     */
    private void deleteOwnWorkout(Workout workout) {
        if (sessionRepository.existsByAssignmentWorkoutId(workout.getId())) {
            workoutAssignmentRepository.findByWorkoutIdAndStudentIdAndStatus(
                            workout.getId(), workout.getStudentOwner().getId(), WorkoutAssignmentStatus.ACTIVE)
                    .ifPresent(a -> {
                        a.setStatus(WorkoutAssignmentStatus.ENDED);
                        a.setEndedAt(LocalDateTime.now());
                        workoutAssignmentRepository.save(a);
                    });
            return;
        }
        workoutAssignmentRepository.deleteByWorkoutId(workout.getId());
        workoutExercisesRepository.deleteByWorkoutId(workout.getId());
        workoutRepository.deleteById(workout.getId());
    }

    public WorkoutResponse getWorkoutById (Long id, String authenticatedEmail){
        Workout workout = findWorkout(id);
        workoutAccessService.assertCanReadWorkout(workout, authenticatedEmail);
        try {
            workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
            return toOwnerResponse(workout);
        } catch (AccessDeniedException notOwner) {
            return toResponse(workout);
        }
    }

    public WorkoutResponse updateById(Long id, UpdateWorkoutRequest request, String authenticatedEmail){
        Workout workout = findWorkout(id);
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        workout.setName(request.name().trim());
        workoutRepository.save(workout);
        return toOwnerResponse(workout);
    }

    @Transactional
    public WorkoutAssignmentResponse assignToStudent(Long workoutId, Long studentId, String authenticatedEmail){
        Workout workout = findWorkout(workoutId);
        if (workout.getTrainer() == null) {
            throw new ConflictException("Treinos montados pelo aluno não podem ser atribuídos a outros alunos.");
        }
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        StudentProfile student = findStudent(studentId);
        workoutAccessService.assertCanWrite(student.getId(), authenticatedEmail);
        return assign(workout, student);
    }

    /** Alunos com o treino ativo (so o personal dono ve). */
    public List<WorkoutAssignmentResponse> activeAssignments(Long workoutId, String authenticatedEmail){
        Workout workout = findWorkout(workoutId);
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        return workoutAssignmentRepository
                .findByWorkoutIdAndStatusOrderByStudentNameAsc(workoutId, WorkoutAssignmentStatus.ACTIVE).stream()
                .map(this::toResponse)
                .toList();
    }

    /** Copia o treino com o plano atual (sem as atribuicoes) para o personal ajustar. */
    @Transactional
    public WorkoutResponse duplicate(Long workoutId, String authenticatedEmail){
        Workout original = findWorkout(workoutId);
        workoutAccessService.assertOwnsWorkout(original, authenticatedEmail);

        String name = original.getName() + " (cópia)";
        Workout copy = workoutRepository.save(Workout.builder()
                .name(name.length() > MAX_NAME_LENGTH ? name.substring(0, MAX_NAME_LENGTH) : name)
                .trainer(original.getTrainer())
                .studentOwner(original.getStudentOwner())
                .build());
        if (original.getStudentOwner() != null) {
            assign(copy, original.getStudentOwner());
        }

        List<WorkoutExercises> plan = workoutExercisesRepository.findByWorkoutIdAndRemovedAtIsNullOrderByPositionAscIdAsc(workoutId);
        for (int i = 0; i < plan.size(); i++) {
            WorkoutExercises item = plan.get(i);
            workoutExercisesRepository.save(WorkoutExercises.builder()
                    .workout(copy)
                    .exercise(item.getExercise())
                    .sets(item.getSets())
                    .reps(item.getReps())
                    .position(i + 1)
                    .restSeconds(item.getRestSeconds())
                    .targetLoad(item.getTargetLoad())
                    .notes(item.getNotes())
                    .build());
        }
        return toOwnerResponse(copy);
    }

    @Transactional
    public void endAssignment(Long workoutId, Long studentId, String authenticatedEmail){
        Workout workout = findWorkout(workoutId);
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        workoutAccessService.assertCanWrite(studentId, authenticatedEmail);

        WorkoutAssignment assignment = workoutAssignmentRepository
                .findByWorkoutIdAndStudentIdAndStatus(workoutId, studentId, WorkoutAssignmentStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Atribuição ativa não encontrada!"));
        assignment.setStatus(WorkoutAssignmentStatus.ENDED);
        assignment.setEndedAt(LocalDateTime.now());
        workoutAssignmentRepository.save(assignment);
    }

}
