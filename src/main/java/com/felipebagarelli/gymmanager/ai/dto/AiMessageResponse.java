package com.felipebagarelli.gymmanager.ai.dto;

import com.felipebagarelli.gymmanager.ai.entity.AiMessageKind;
import com.felipebagarelli.gymmanager.ai.entity.AiRole;

import java.time.LocalDateTime;

public record AiMessageResponse(Long id, AiRole role, String body, LocalDateTime createdAt,
                                AiMessageKind kind, EquipmentAnalysis equipment) {

    /** Mensagem de texto comum (sem analise de foto). */
    public AiMessageResponse(Long id, AiRole role, String body, LocalDateTime createdAt) {
        this(id, role, body, createdAt, AiMessageKind.TEXT, null);
    }
}
