package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutExercisesResponse;
import com.felipebagarelli.gymmanager.service.WorkoutExerciseService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/workout-exercises")
public class WorkoutExercisesController {

    private final WorkoutExerciseService workoutExerciseService;

    public WorkoutExercisesController(WorkoutExerciseService workoutExerciseService) {
        this.workoutExerciseService = workoutExerciseService;
    }

    @PostMapping
    public WorkoutExercisesResponse addWorkoutExercise(@RequestBody @Valid CreateWorkoutExerciseRequest request, @AuthenticationPrincipal Jwt jwt) {
        return workoutExerciseService.addWorkoutExercise(request, jwt.getSubject());
    }

    @GetMapping("/workout/{id}")
    public List<WorkoutExercisesResponse> allWorkoutExercises(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return workoutExerciseService.allWorkoutExercises(id, jwt.getSubject());
    }

    @DeleteMapping("/{id}")
    public void deleteWorkoutExercise(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        workoutExerciseService.deleteById(id, jwt.getSubject());
    }

    @PutMapping("/{id}")
    public WorkoutExercisesResponse updateWorkoutExercise(@PathVariable Long id, @RequestBody @Valid CreateWorkoutExerciseRequest request, @AuthenticationPrincipal Jwt jwt) {
        return workoutExerciseService.updateById(request, id, jwt.getSubject());
    }

    @GetMapping("/{id}")
    public WorkoutExercisesResponse getWorkoutExerciseById(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt){
        return workoutExerciseService.getById(id, jwt.getSubject());
    }
}
