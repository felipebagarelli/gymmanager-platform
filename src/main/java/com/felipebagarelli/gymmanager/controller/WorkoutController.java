package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateMemberRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.response.MemberResponse;
import com.felipebagarelli.gymmanager.dto.response.WorkoutResponse;
import com.felipebagarelli.gymmanager.service.WorkoutService;
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
    public WorkoutResponse addWorkout(@RequestBody CreateWorkoutRequest request ){
        return workoutService.addWorkout(request);
    }

    @GetMapping("/member/{id}")
    public List<WorkoutResponse> allWorkout(@PathVariable Long id){
        return workoutService.allWorkout(id);
    }

    @GetMapping("/{id}")
    public WorkoutResponse getWorkoutById(@PathVariable Long id){
        return workoutService.getWorkoutById(id);
    }

    @DeleteMapping("/{id}")
    public void deleteWorkoutById(@PathVariable Long id){
        workoutService.deleteById(id);
    }

    @PutMapping("/{id}")
    public WorkoutResponse updateWorkoutById(@PathVariable Long id, @RequestBody UpdateWorkoutRequest request){
        return workoutService.updateById(id, request);
    }


}
