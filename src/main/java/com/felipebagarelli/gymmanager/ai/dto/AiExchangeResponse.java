package com.felipebagarelli.gymmanager.ai.dto;

public record AiExchangeResponse(AiMessageResponse question, AiMessageResponse answer, long remainingToday) {
}
