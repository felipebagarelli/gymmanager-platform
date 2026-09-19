package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.CreateExerciseRequest;
import com.felipebagarelli.gymmanager.dto.request.CreateMemberRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateMemberRequest;
import com.felipebagarelli.gymmanager.dto.response.ExerciseResponse;
import com.felipebagarelli.gymmanager.dto.response.MemberResponse;
import com.felipebagarelli.gymmanager.service.ExerciseService;
import com.felipebagarelli.gymmanager.service.MemberService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/exercises")
@CrossOrigin(origins = "http://localhost:5173")
public class ExerciseController {

    private ExerciseService exerciseService;

    ExerciseController (ExerciseService exerciseService){
        this.exerciseService = exerciseService;
    }

   @PostMapping
    public ExerciseResponse addExercise(@RequestBody CreateExerciseRequest request){
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
    public ExerciseResponse updateExercise(@PathVariable Long id, @RequestBody CreateExerciseRequest request){
        return exerciseService.updateById(request, id);
   }

}
