package com.felipebagarelli.gymmanager.dto.request;

import jakarta.validation.constraints.NotBlank;

public record CreateWorkoutRequest(
        @NotBlank String name,
        Long studentId
) {
}
