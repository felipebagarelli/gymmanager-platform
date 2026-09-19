package com.felipebagarelli.gymmanager.dto.request;

public record CreateWorkoutRequest(
        String name,
        Long memberId
) {
}
