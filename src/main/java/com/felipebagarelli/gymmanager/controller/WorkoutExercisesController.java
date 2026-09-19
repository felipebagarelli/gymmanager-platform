package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutExercisesResponse;
import com.felipebagarelli.gymmanager.service.WorkoutExerciseService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/workout-exercises")
@CrossOrigin(origins = "http://localhost:5173")
public class WorkoutExercisesController {

    private final WorkoutExerciseService workoutExerciseService;

    public WorkoutExercisesController(WorkoutExerciseService workoutExerciseService) {
        this.workoutExerciseService = workoutExerciseService;
    }

    @PostMapping
    public WorkoutExercisesResponse addWorkoutExercise(@RequestBody CreateWorkoutExerciseRequest request) {
        return workoutExerciseService.addWorkoutExercise(request);
    }

    @GetMapping("/workout/{id}")
    public List<WorkoutExercisesResponse> allWorkoutExercises(@PathVariable Long id) {
        return workoutExerciseService.allWorkoutExercises(id);
    }

    @DeleteMapping("/{id}")
    public void deleteWorkoutExercise(@PathVariable Long id) {
        workoutExerciseService.deleteById(id);
    }

    @PutMapping("/{id}")
    public WorkoutExercisesResponse updateWorkoutExercise(@PathVariable Long id, @RequestBody CreateWorkoutExerciseRequest request) {
        return workoutExerciseService.updateById(request, id);
    }

    @GetMapping("/{id}")
    public WorkoutExercisesResponse getWorkoutExerciseById(@PathVariable Long id){
        return workoutExerciseService.getById(id);
    }
}