package com.felipebagarelli.gymmanager.trainer.controller;

import com.felipebagarelli.gymmanager.trainer.dto.request.RegisterTrainerRequest;
import com.felipebagarelli.gymmanager.trainer.dto.response.TrainerProfileResponse;
import com.felipebagarelli.gymmanager.trainer.service.TrainerService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
public class TrainerController {

    private final TrainerService trainerService;

    public TrainerController(TrainerService trainerService) {
        this.trainerService = trainerService;
    }

    @PostMapping("/api/v1/auth/register-trainer")
    public TrainerProfileResponse registerTrainer(@RequestBody @Valid RegisterTrainerRequest request) {
        return trainerService.registerTrainer(request);
    }

    @GetMapping("/api/v1/trainers/me")
    public TrainerProfileResponse getMyProfile(@AuthenticationPrincipal Jwt jwt) {
        return trainerService.getMyProfile(jwt.getSubject());
    }

    @GetMapping("/api/v1/trainers/{id}")
    public TrainerProfileResponse getTrainerById(@PathVariable Long id) {
        return trainerService.getTrainerById(id);
    }
}
