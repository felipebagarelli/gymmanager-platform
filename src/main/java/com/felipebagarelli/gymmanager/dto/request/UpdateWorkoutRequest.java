package com.felipebagarelli.gymmanager.dto.request;

public record UpdateWorkoutRequest(
        String name,
        Long memberId
) {
}
