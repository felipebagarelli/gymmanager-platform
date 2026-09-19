package com.felipebagarelli.gymmanager.ai.dto;

import com.felipebagarelli.gymmanager.ai.entity.AiRole;

import java.time.LocalDateTime;

public record AiMessageResponse(Long id, AiRole role, String body, LocalDateTime createdAt) {
}
