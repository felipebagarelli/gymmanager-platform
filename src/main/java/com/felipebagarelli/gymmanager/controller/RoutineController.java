package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.RoutineDtos.BatchRoutineRequest;
import com.felipebagarelli.gymmanager.dto.RoutineDtos.RoutineResponse;
import com.felipebagarelli.gymmanager.dto.RoutineDtos.SetRoutineRequest;
import com.felipebagarelli.gymmanager.dto.RoutineDtos.SkipRequest;
import com.felipebagarelli.gymmanager.service.RoutineService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Esquema de treino do aluno: dias da semana ou sequencia (F3). */
@RestController
public class RoutineController {

    private final RoutineService routineService;

    public RoutineController(RoutineService routineService) {
        this.routineService = routineService;
    }

    @GetMapping("/workouts/student/{studentId}/routine")
    public RoutineResponse get(@PathVariable Long studentId, @AuthenticationPrincipal Jwt jwt) {
        return routineService.get(studentId, jwt.getSubject());
    }

    @PutMapping("/workouts/student/{studentId}/routine")
    public RoutineResponse set(@PathVariable Long studentId, @RequestBody @Valid SetRoutineRequest request,
                               @AuthenticationPrincipal Jwt jwt) {
        return routineService.set(studentId, request.mode(), request.workoutIds(), jwt.getSubject());
    }

    @PostMapping("/workouts/student/{studentId}/routine/next")
    public RoutineResponse skipTo(@PathVariable Long studentId, @RequestBody @Valid SkipRequest request,
                                  @AuthenticationPrincipal Jwt jwt) {
        return routineService.skipTo(studentId, request.workoutId(), jwt.getSubject());
    }

    @PostMapping("/workouts/routine/batch")
    public List<RoutineResponse> applyToStudents(@RequestBody @Valid BatchRoutineRequest request, @AuthenticationPrincipal Jwt jwt) {
        return routineService.applyToStudents(request.studentIds(), request.workoutIds(), jwt.getSubject());
    }
}
