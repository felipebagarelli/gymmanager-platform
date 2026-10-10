package com.felipebagarelli.gymmanager.ai.controller;

import com.felipebagarelli.gymmanager.ai.dto.AiExchangeResponse;
import com.felipebagarelli.gymmanager.ai.dto.AiMessageResponse;
import com.felipebagarelli.gymmanager.ai.dto.AiUsageResponse;
import com.felipebagarelli.gymmanager.ai.dto.AskRequest;
import com.felipebagarelli.gymmanager.ai.service.AiAssistantService;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.InvalidImageException;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    static final int MAX_QUESTION_LENGTH = 1000;

    private final AiAssistantService assistantService;

    public AiController(AiAssistantService assistantService) {
        this.assistantService = assistantService;
    }

    @GetMapping("/messages")
    public List<AiMessageResponse> history(@RequestParam(defaultValue = "50") int limit,
                                           @AuthenticationPrincipal Jwt jwt) {
        return assistantService.history(jwt.getSubject(), limit);
    }

    @PostMapping(value = "/messages", consumes = MediaType.APPLICATION_JSON_VALUE)
    public AiExchangeResponse ask(@RequestBody @Valid AskRequest request, @AuthenticationPrincipal Jwt jwt) {
        return assistantService.ask(jwt.getSubject(), request.question());
    }

    /** Pergunta com foto do aparelho: texto opcional e imagem opcional (pelo menos um dos dois). */
    @PostMapping(value = "/messages", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AiExchangeResponse askMultipart(@RequestParam(value = "question", required = false) String question,
                                           @RequestPart(value = "image", required = false) MultipartFile image,
                                           @AuthenticationPrincipal Jwt jwt) {
        boolean hasImage = image != null && !image.isEmpty();
        boolean hasText = question != null && !question.isBlank();
        if (!hasImage && !hasText) {
            throw new BadRequestException("Envie uma pergunta ou uma foto.");
        }
        if (hasText && question.trim().length() > MAX_QUESTION_LENGTH) {
            throw new BadRequestException("A pergunta pode ter até " + MAX_QUESTION_LENGTH + " caracteres.");
        }
        if (!hasImage) {
            return assistantService.ask(jwt.getSubject(), question);
        }
        try {
            return assistantService.askWithPhoto(jwt.getSubject(), question, image.getBytes());
        } catch (IOException e) {
            throw new InvalidImageException("Não foi possível ler a foto enviada.");
        }
    }

    @GetMapping("/usage")
    public AiUsageResponse usage(@AuthenticationPrincipal Jwt jwt) {
        return assistantService.usage(jwt.getSubject());
    }
}
