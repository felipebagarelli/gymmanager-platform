package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutExercisesResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class WorkoutExerciseService {

    private final WorkoutExercisesRepository workoutExercisesRepository;
    private final WorkoutRepository workoutRepository;
    private final ExerciseRepository exerciseRepository;
    private final WorkoutAccessService workoutAccessService;

    public WorkoutExerciseService(WorkoutExercisesRepository workoutExercisesRepository,
                                  WorkoutRepository workoutRepository,
                                  ExerciseRepository exerciseRepository,
                                  WorkoutAccessService workoutAccessService){
        this.workoutRepository = workoutRepository;
        this.exerciseRepository = exerciseRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
        this.workoutAccessService = workoutAccessService;
    }

    public WorkoutExercisesResponse toResponse(WorkoutExercises workoutExercises){
        return new WorkoutExercisesResponse(
                workoutExercises.getId(),
                workoutExercises.getExercise().getId(),
                workoutExercises.getWorkout().getId(),
                workoutExercises.getReps(),
                workoutExercises.getSets(),
                workoutExercises.getPosition(),
                workoutExercises.getRestSeconds(),
                workoutExercises.getTargetLoad(),
                workoutExercises.getNotes());
    }

    private Workout findWorkout(Long id){
        return workoutRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Treino não encontrado!"));
    }

    private Exercises findExercise(Long id){
        return exerciseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Exercício não encontrado!"));
    }

    private WorkoutExercises findWorkoutExercise(Long id){
        return workoutExercisesRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Exercício não encontrado!"));
    }


    public WorkoutExercisesResponse addWorkoutExercise(CreateWorkoutExerciseRequest request, String authenticatedEmail) {

        Exercises exercise = findExercise(request.exerciseId());
        Workout workout = findWorkout(request.workoutId());
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);

        WorkoutExercises workoutExercise = WorkoutExercises.builder()
                .exercise(exercise)
                .workout(workout)
                .sets(request.sets())
                .reps(request.reps())
                .position(request.position())
                .restSeconds(request.restSeconds())
                .targetLoad(request.targetLoad())
                .notes(request.notes())
                .build();

        workoutExercisesRepository.save(workoutExercise);

        return toResponse(workoutExercise);
    }


    public List<WorkoutExercisesResponse> allWorkoutExercises(Long workoutId, String authenticatedEmail) {
        Workout workout = findWorkout(workoutId);
        workoutAccessService.assertCanReadWorkout(workout, authenticatedEmail);

        return workoutExercisesRepository.findByWorkoutIdOrderByPositionAscIdAsc(workoutId).stream()
                .map(this::toResponse)
                .toList();
    }


    public void deleteById(Long id, String authenticatedEmail) {
        WorkoutExercises workoutExercise = findWorkoutExercise(id);
        workoutAccessService.assertOwnsWorkout(workoutExercise.getWorkout(), authenticatedEmail);
        workoutExercisesRepository.deleteById(id);
    }


    public WorkoutExercisesResponse updateById(
            CreateWorkoutExerciseRequest request,
            Long id,
            String authenticatedEmail) {

        WorkoutExercises workoutExercise = findWorkoutExercise(id);
        workoutAccessService.assertOwnsWorkout(workoutExercise.getWorkout(), authenticatedEmail);

        Exercises exercise = findExercise(request.exerciseId());
        Workout workout = findWorkout(request.workoutId());
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);

        workoutExercise.setExercise(exercise);
        workoutExercise.setWorkout(workout);
        workoutExercise.setReps(request.reps());
        workoutExercise.setSets(request.sets());
        workoutExercise.setPosition(request.position());
        workoutExercise.setRestSeconds(request.restSeconds());
        workoutExercise.setTargetLoad(request.targetLoad());
        workoutExercise.setNotes(request.notes());

        workoutExercisesRepository.save(workoutExercise);

        return toResponse(workoutExercise);
    }

    public WorkoutExercisesResponse getById(Long id, String authenticatedEmail){
        WorkoutExercises workoutExercise = findWorkoutExercise(id);
        workoutAccessService.assertCanReadWorkout(workoutExercise.getWorkout(), authenticatedEmail);
        return toResponse(workoutExercise);
    }

}
