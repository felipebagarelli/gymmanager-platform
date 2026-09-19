package com.felipebagarelli.gymmanager.service;


import com.felipebagarelli.gymmanager.dto.request.CreateExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.ExerciseResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ExerciseService {

    private final ExerciseRepository exerciseRepository;

    public ExerciseService(ExerciseRepository exerciseRepository){
        this.exerciseRepository = exerciseRepository;
    }

    private ExerciseResponse toResponse (Exercises exercise){
        return new ExerciseResponse(exercise.getId(), exercise.getName(), exercise.getMuscleGroup());
    }

    public ExerciseResponse addExercise(CreateExerciseRequest request) {
        Exercises exercise = Exercises.builder()
                .name(request.name())
                .muscleGroup(request.muscleGroup())
                .build();
        exerciseRepository.save(exercise);

        return toResponse(exercise);
    }

    public List<ExerciseResponse> allExercises (){
        List<Exercises> listExercises = exerciseRepository.findAll();
        return listExercises.stream().map(this::toResponse).toList();
    }

    public ExerciseResponse getExercisesById(Long id){
        return toResponse(exerciseRepository.findById(id).orElseThrow());
    }

    public void deleteById (Long id){
        exerciseRepository.deleteById(id);
    }

    public ExerciseResponse updateById(CreateExerciseRequest request, Long id){
        Exercises exercise = exerciseRepository.findById(id).orElseThrow();
        exercise.setName(request.name());
        exercise.setMuscleGroup(request.muscleGroup());
        exerciseRepository.save(exercise);
        return toResponse(exercise);
    }


}
