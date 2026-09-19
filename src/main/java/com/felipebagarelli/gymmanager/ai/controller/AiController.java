package com.felipebagarelli.gymmanager.ai.controller;

import com.felipebagarelli.gymmanager.ai.dto.AiExchangeResponse;
import com.felipebagarelli.gymmanager.ai.dto.AiMessageResponse;
import com.felipebagarelli.gymmanager.ai.dto.AiUsageResponse;
import com.felipebagarelli.gymmanager.ai.dto.AskRequest;
import com.felipebagarelli.gymmanager.ai.service.AiAssistantService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final AiAssistantService assistantService;

    public AiController(AiAssistantService assistantService) {
        this.assistantService = assistantService;
    }

    @GetMapping("/messages")
    public List<AiMessageResponse> history(@RequestParam(defaultValue = "50") int limit,
                                           @AuthenticationPrincipal Jwt jwt) {
        return assistantService.history(jwt.getSubject(), limit);
    }

    @PostMapping("/messages")
    public AiExchangeResponse ask(@RequestBody @Valid AskRequest request, @AuthenticationPrincipal Jwt jwt) {
        return assistantService.ask(jwt.getSubject(), request.question());
    }

    @GetMapping("/usage")
    public AiUsageResponse usage(@AuthenticationPrincipal Jwt jwt) {
        return assistantService.usage(jwt.getSubject());
    }
}
