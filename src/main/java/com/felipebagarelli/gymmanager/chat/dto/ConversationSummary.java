package com.felipebagarelli.gymmanager.chat.dto;

public record ConversationSummary(
        Long id,
        Long studentId,
        String studentName,
        Long trainerId,
        String trainerName,
        MessageResponse lastMessage,
        long unreadCount,
        boolean canSend
) {
}
