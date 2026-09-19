package com.felipebagarelli.gymmanager.service;


import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutAssignmentResponse;
import com.felipebagarelli.gymmanager.dto.response.WorkoutResponse;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class WorkoutService {

    private final WorkoutRepository workoutRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final WorkoutExercisesRepository workoutExercisesRepository;
    private final WorkoutAssignmentRepository workoutAssignmentRepository;
    private final WorkoutAccessService workoutAccessService;

    public WorkoutService(WorkoutRepository workoutRepository,
                          StudentProfileRepository studentProfileRepository,
                          TrainerProfileRepository trainerProfileRepository,
                          WorkoutExercisesRepository workoutExercisesRepository,
                          WorkoutAssignmentRepository workoutAssignmentRepository,
                          WorkoutAccessService workoutAccessService){
        this.workoutRepository = workoutRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
        this.workoutAssignmentRepository = workoutAssignmentRepository;
        this.workoutAccessService = workoutAccessService;
    }

    public WorkoutResponse toResponse(Workout workout){
        Long trainerId = workout.getTrainer() != null ? workout.getTrainer().getId() : null;
        return new WorkoutResponse(workout.getId(), workout.getName(), trainerId);
    }

    private WorkoutAssignmentResponse toResponse(WorkoutAssignment a){
        return new WorkoutAssignmentResponse(a.getId(), a.getWorkout().getId(), a.getStudent().getId(),
                a.getStatus(), a.getStartedAt(), a.getEndedAt());
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

    @Transactional
    public WorkoutResponse addWorkout(CreateWorkoutRequest request, String authenticatedEmail){
        TrainerProfile trainer = trainerProfileRepository.findByUserEmail(authenticatedEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));

        StudentProfile student = null;
        if (request.studentId() != null) {
            student = findStudent(request.studentId());
            workoutAccessService.assertCanWrite(student.getId(), authenticatedEmail);
        }

        Workout workout = workoutRepository.save(Workout.builder()
                .name(request.name())
                .trainer(trainer)
                .build());

        if (student != null) {
            assign(workout, student);
        }
        return toResponse(workout);
    }

    public List<WorkoutResponse> myWorkouts(String authenticatedEmail){
        TrainerProfile trainer = trainerProfileRepository.findByUserEmail(authenticatedEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
        return workoutRepository.findByTrainerId(trainer.getId()).stream().map(this::toResponse).toList();
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
        if (workoutAssignmentRepository.existsByWorkoutId(id)) {
            throw new ConflictException("Este treino já foi atribuído a alunos; encerre as atribuições em vez de excluí-lo.");
        }
        workoutExercisesRepository.deleteByWorkoutId(id);
        workoutRepository.deleteById(id);
    }

    public WorkoutResponse getWorkoutById (Long id, String authenticatedEmail){
        Workout workout = findWorkout(id);
        workoutAccessService.assertCanReadWorkout(workout, authenticatedEmail);
        return toResponse(workout);
    }

    public WorkoutResponse updateById(Long id, UpdateWorkoutRequest request, String authenticatedEmail){
        Workout workout = findWorkout(id);
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        workout.setName(request.name());
        workoutRepository.save(workout);
        return toResponse(workout);
    }

    @Transactional
    public WorkoutAssignmentResponse assignToStudent(Long workoutId, Long studentId, String authenticatedEmail){
        Workout workout = findWorkout(workoutId);
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        StudentProfile student = findStudent(studentId);
        workoutAccessService.assertCanWrite(student.getId(), authenticatedEmail);
        return assign(workout, student);
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
