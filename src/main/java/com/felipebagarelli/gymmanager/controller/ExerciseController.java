package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.CreateExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.ExerciseResponse;
import com.felipebagarelli.gymmanager.service.ExerciseService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
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
    public ExerciseResponse addExercise(@RequestBody @Valid CreateExerciseRequest request, @AuthenticationPrincipal Jwt jwt){
        return exerciseService.addExercise(request, jwt.getSubject());
   }

   @GetMapping
    public List<ExerciseResponse> allExercises(@AuthenticationPrincipal Jwt jwt){
        return exerciseService.allExercises(jwt.getSubject());
   }

   @GetMapping("/{id}")
   public ExerciseResponse getExerciseById(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt){
        return exerciseService.getExercisesById(id, jwt.getSubject());
   }

   @DeleteMapping("/{id}")
    public void deleteExercise(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt){
        exerciseService.deleteById(id, jwt.getSubject());
   }

   @PutMapping("/{id}")
    public ExerciseResponse updateExercise(@PathVariable Long id, @RequestBody @Valid CreateExerciseRequest request, @AuthenticationPrincipal Jwt jwt){
        return exerciseService.updateById(request, id, jwt.getSubject());
   }

}
