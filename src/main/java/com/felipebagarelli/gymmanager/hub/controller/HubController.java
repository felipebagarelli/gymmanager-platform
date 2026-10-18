package com.felipebagarelli.gymmanager.hub.controller;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.HireRequest;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.PublicProfileRequest;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.PublicProfileResponse;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.TrainerCard;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.TrainerDetail;
import com.felipebagarelli.gymmanager.hub.entity.TrainerSpecialty;
import com.felipebagarelli.gymmanager.hub.service.HubService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class HubController {

    private final HubService hubService;

    public HubController(HubService hubService) {
        this.hubService = hubService;
    }

    // ---- personal: o proprio perfil publico

    @GetMapping("/api/v1/trainers/me/public-profile")
    public PublicProfileResponse myPublicProfile(@AuthenticationPrincipal Jwt jwt) {
        return hubService.myPublicProfile(jwt.getSubject());
    }

    @PutMapping("/api/v1/trainers/me/public-profile")
    public PublicProfileResponse updatePublicProfile(@RequestBody @Valid PublicProfileRequest request, @AuthenticationPrincipal Jwt jwt) {
        return hubService.updatePublicProfile(request, jwt.getSubject());
    }

    // ---- aluno: busca e contratacao

    @GetMapping("/api/v1/hub/trainers")
    public List<TrainerCard> search(@RequestParam(required = false) String q,
                                    @RequestParam(required = false) TrainerSpecialty specialty,
                                    @RequestParam(required = false) Boolean online,
                                    @RequestParam(required = false) String city) {
        return hubService.search(q, specialty, online, city);
    }

    @GetMapping("/api/v1/hub/trainers/{id}")
    public TrainerDetail detail(@PathVariable Long id) {
        return hubService.detail(id);
    }

    @PostMapping("/api/v1/hub/trainers/{id}/hire")
    public UrlResponse hire(@PathVariable Long id, @RequestBody @Valid HireRequest request, @AuthenticationPrincipal Jwt jwt) {
        return hubService.hire(id, request.planId(), jwt.getSubject());
    }
}
