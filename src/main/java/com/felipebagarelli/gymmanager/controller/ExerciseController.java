package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.CreateExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.ExerciseResponse;
import com.felipebagarelli.gymmanager.service.ExerciseService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/exercises")
public class ExerciseController {

    private ExerciseService exerciseService;

    ExerciseController (ExerciseService exerciseService){
        this.exerciseService = exerciseService;
    }

   @PostMapping
    public ExerciseResponse addExercise(@RequestBody @Valid CreateExerciseRequest request){
        return exerciseService.addExercise(request);
   }

   @GetMapping
    public List<ExerciseResponse> allExercises(){
        return exerciseService.allExercises();
   }

   @GetMapping("/{id}")
   public ExerciseResponse getExerciseById(@PathVariable Long id){
        return exerciseService.getExercisesById(id);
   }

   @DeleteMapping("/{id}")
    public void deleteExercise(@PathVariable Long id){
        exerciseService.deleteById(id);
   }

   @PutMapping("/{id}")
    public ExerciseResponse updateExercise(@PathVariable Long id, @RequestBody @Valid CreateExerciseRequest request){
        return exerciseService.updateById(request, id);
   }

}
