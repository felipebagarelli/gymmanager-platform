package com.felipebagarelli.gymmanager.aiworkout.controller;

import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.CreateProposalRequest;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.EligibilityResponse;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposalResponse;
import com.felipebagarelli.gymmanager.aiworkout.service.AiWorkoutProposalService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/** Propostas de treino da IA (so o proprio aluno; rotas /api/v1/ai/** ja sao do STUDENT). */
@RestController
public class AiWorkoutProposalController {

    private final AiWorkoutProposalService service;

    public AiWorkoutProposalController(AiWorkoutProposalService service) {
        this.service = service;
    }

    @GetMapping("/api/v1/ai/workout-proposals/eligibility")
    public EligibilityResponse eligibility(@AuthenticationPrincipal Jwt jwt) {
        return service.eligibility(jwt.getSubject());
    }

    @PostMapping("/api/v1/ai/workout-proposals")
    @ResponseStatus(HttpStatus.CREATED)
    public ProposalResponse propose(@RequestBody @Valid CreateProposalRequest request, @AuthenticationPrincipal Jwt jwt) {
        return service.propose(jwt.getSubject(), request.note());
    }

    @GetMapping("/api/v1/ai/workout-proposals/{id}")
    public ProposalResponse get(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return service.get(jwt.getSubject(), id);
    }

    @PostMapping("/api/v1/ai/workout-proposals/{id}/accept")
    public ProposalResponse accept(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return service.accept(jwt.getSubject(), id);
    }

    @PostMapping("/api/v1/ai/workout-proposals/{id}/reject")
    public ProposalResponse reject(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return service.reject(jwt.getSubject(), id);
    }
}
