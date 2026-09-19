package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutExercisesResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
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

    public WorkoutExerciseService(WorkoutExercisesRepository workoutExercisesRepository,
                                  WorkoutRepository workoutRepository,
                                  ExerciseRepository exerciseRepository){
        this.workoutRepository = workoutRepository;
        this.exerciseRepository = exerciseRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
    }

    public WorkoutExercisesResponse toResponse(WorkoutExercises workoutExercises){
        return new WorkoutExercisesResponse(workoutExercises.getId(), workoutExercises.getExercise().getId(), workoutExercises.getWorkout().getId(), workoutExercises.getReps(), workoutExercises.getSets());


    }


    public WorkoutExercisesResponse addWorkoutExercise(CreateWorkoutExerciseRequest request) {

        Exercises exercise = exerciseRepository.findById(request.exerciseId())
                .orElseThrow();

        Workout workout = workoutRepository.findById(request.workoutId())
                .orElseThrow();

        WorkoutExercises workoutExercise = WorkoutExercises.builder()
                .exercise(exercise)
                .workout(workout)
                .sets(request.sets())
                .reps(request.reps())
                .build();

        workoutExercisesRepository.save(workoutExercise);

        return toResponse(workoutExercise);
    }


    public List<WorkoutExercisesResponse> allWorkoutExercises(Long id) {
        List<WorkoutExercises> workoutExercises =
                workoutExercisesRepository.findByWorkoutId(id);

        return workoutExercises.stream()
                .map(this::toResponse)
                .toList();
    }


    public void deleteById(Long id) {
        workoutExercisesRepository.deleteById(id);
    }


    public WorkoutExercisesResponse updateById(
            CreateWorkoutExerciseRequest request,
            Long id) {

        WorkoutExercises workoutExercise =
                workoutExercisesRepository.findById(id)
                        .orElseThrow();

        Exercises exercise = exerciseRepository.findById(request.exerciseId())
                .orElseThrow();

        Workout workout = workoutRepository.findById(request.workoutId())
                .orElseThrow();

        workoutExercise.setExercise(exercise);
        workoutExercise.setWorkout(workout);
        workoutExercise.setReps(request.reps());
        workoutExercise.setSets(request.sets());

        workoutExercisesRepository.save(workoutExercise);

        return toResponse(workoutExercise);
    }

    public WorkoutExercisesResponse getById(Long id){
        return toResponse(workoutExercisesRepository.findById(id).orElseThrow());
    }

}
