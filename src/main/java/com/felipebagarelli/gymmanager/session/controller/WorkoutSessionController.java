package com.felipebagarelli.gymmanager.session.controller;

import com.felipebagarelli.gymmanager.session.dto.PerformanceResponse;
import com.felipebagarelli.gymmanager.session.dto.RecordPerformanceRequest;
import com.felipebagarelli.gymmanager.session.dto.StartSessionRequest;
import com.felipebagarelli.gymmanager.session.dto.UpdatePerformanceRequest;
import com.felipebagarelli.gymmanager.session.dto.WorkoutSessionResponse;
import com.felipebagarelli.gymmanager.session.service.WorkoutSessionService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class WorkoutSessionController {

    private final WorkoutSessionService sessionService;

    public WorkoutSessionController(WorkoutSessionService sessionService) {
        this.sessionService = sessionService;
    }

    @PostMapping("/api/v1/workout-sessions")
    public WorkoutSessionResponse start(@RequestBody @Valid StartSessionRequest request, @AuthenticationPrincipal Jwt jwt) {
        return sessionService.start(request.workoutId(), jwt.getSubject());
    }

    @GetMapping("/api/v1/workout-sessions/{id}")
    public WorkoutSessionResponse getById(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return sessionService.getById(id, jwt.getSubject());
    }

    @GetMapping("/api/v1/students/{studentId}/workout-sessions")
    public List<WorkoutSessionResponse> listByStudent(@PathVariable Long studentId, @AuthenticationPrincipal Jwt jwt) {
        return sessionService.listByStudent(studentId, jwt.getSubject());
    }

    @PostMapping("/api/v1/workout-sessions/{id}/performances")
    public PerformanceResponse addPerformance(@PathVariable Long id,
                                               @RequestBody @Valid RecordPerformanceRequest request,
                                               @AuthenticationPrincipal Jwt jwt) {
        return sessionService.addPerformance(id, request, jwt.getSubject());
    }

    @PutMapping("/api/v1/workout-sessions/{id}/performances/{performanceId}")
    public PerformanceResponse updatePerformance(@PathVariable Long id,
                                                  @PathVariable Long performanceId,
                                                  @RequestBody @Valid UpdatePerformanceRequest request,
                                                  @AuthenticationPrincipal Jwt jwt) {
        return sessionService.updatePerformance(id, performanceId, request, jwt.getSubject());
    }

    @DeleteMapping("/api/v1/workout-sessions/{id}/performances/{performanceId}")
    public void deletePerformance(@PathVariable Long id, @PathVariable Long performanceId, @AuthenticationPrincipal Jwt jwt) {
        sessionService.deletePerformance(id, performanceId, jwt.getSubject());
    }

    @PostMapping("/api/v1/workout-sessions/{id}/finish")
    public WorkoutSessionResponse finish(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return sessionService.finish(id, jwt.getSubject());
    }
}
