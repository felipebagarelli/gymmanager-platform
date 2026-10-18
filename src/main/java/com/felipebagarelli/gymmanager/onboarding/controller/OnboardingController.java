package com.felipebagarelli.gymmanager.onboarding.controller;

import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.HealthScreeningRequest;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.HealthScreeningResponse;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.OnboardingResponse;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainingProfileRequest;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainingProfileResponse;
import com.felipebagarelli.gymmanager.onboarding.service.OnboardingService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/** Onboarding e triagem de saude do proprio aluno. */
@RestController
public class OnboardingController {

    private final OnboardingService onboardingService;

    public OnboardingController(OnboardingService onboardingService) {
        this.onboardingService = onboardingService;
    }

    @GetMapping("/api/v1/students/me/onboarding")
    public OnboardingResponse status(@AuthenticationPrincipal Jwt jwt) {
        return onboardingService.status(jwt.getSubject());
    }

    @PutMapping("/api/v1/students/me/training-profile")
    public TrainingProfileResponse saveTrainingProfile(@RequestBody @Valid TrainingProfileRequest request,
                                                       @AuthenticationPrincipal Jwt jwt) {
        return onboardingService.saveTrainingProfile(request, jwt.getSubject());
    }

    @PostMapping("/api/v1/students/me/health-screening")
    @ResponseStatus(HttpStatus.CREATED)
    public HealthScreeningResponse answerScreening(@RequestBody @Valid HealthScreeningRequest request,
                                                   @AuthenticationPrincipal Jwt jwt) {
        return onboardingService.answerScreening(request.answers(), jwt.getSubject());
    }
}
