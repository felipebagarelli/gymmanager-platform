package com.felipebagarelli.gymmanager.chat.dto;

import com.felipebagarelli.gymmanager.chat.entity.MessageSender;

import java.time.LocalDateTime;

public record MessageResponse(
        Long id,
        Long conversationId,
        MessageSender senderRole,
        String body,
        LocalDateTime createdAt
) {
}
