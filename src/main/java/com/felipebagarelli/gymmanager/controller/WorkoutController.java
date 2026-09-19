package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.AssignWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutAssignmentResponse;
import com.felipebagarelli.gymmanager.dto.response.WorkoutResponse;
import com.felipebagarelli.gymmanager.service.WorkoutService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/workouts")
@CrossOrigin(origins = "http://localhost:5173")
public class WorkoutController {

    private WorkoutService workoutService;

    public WorkoutController(WorkoutService workoutService){
        this.workoutService = workoutService;
    }

    @PostMapping
    public WorkoutResponse addWorkout(@RequestBody @Valid CreateWorkoutRequest request, @AuthenticationPrincipal Jwt jwt){
        return workoutService.addWorkout(request, jwt.getSubject());
    }

    @GetMapping
    public List<WorkoutResponse> myWorkouts(@AuthenticationPrincipal Jwt jwt){
        return workoutService.myWorkouts(jwt.getSubject());
    }

    @GetMapping("/student/{id}")
    public List<WorkoutResponse> allWorkout(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt){
        return workoutService.allWorkout(id, jwt.getSubject());
    }

    @GetMapping("/{id}")
    public WorkoutResponse getWorkoutById(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt){
        return workoutService.getWorkoutById(id, jwt.getSubject());
    }

    @DeleteMapping("/{id}")
    public void deleteWorkoutById(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt){
        workoutService.deleteById(id, jwt.getSubject());
    }

    @PutMapping("/{id}")
    public WorkoutResponse updateWorkoutById(@PathVariable Long id, @RequestBody @Valid UpdateWorkoutRequest request, @AuthenticationPrincipal Jwt jwt){
        return workoutService.updateById(id, request, jwt.getSubject());
    }

    @PostMapping("/{id}/assignments")
    public WorkoutAssignmentResponse assignToStudent(@PathVariable Long id, @RequestBody @Valid AssignWorkoutRequest request, @AuthenticationPrincipal Jwt jwt){
        return workoutService.assignToStudent(id, request.studentId(), jwt.getSubject());
    }

    @DeleteMapping("/{id}/assignments/{studentId}")
    public void endAssignment(@PathVariable Long id, @PathVariable Long studentId, @AuthenticationPrincipal Jwt jwt){
        workoutService.endAssignment(id, studentId, jwt.getSubject());
    }

}
