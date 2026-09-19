package com.felipebagarelli.gymmanager.ai.dto;

public record AiUsageResponse(long dailyLimit, long usedToday, long remainingToday) {
}
