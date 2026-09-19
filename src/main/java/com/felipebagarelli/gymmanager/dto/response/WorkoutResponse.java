package com.felipebagarelli.gymmanager.dto.response;

public record WorkoutResponse(
        Long id,
        String name,
        Long trainerId
) {
}
