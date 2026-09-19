package com.felipebagarelli.gymmanager.dto.request;

import jakarta.validation.constraints.NotBlank;

public record UpdateWorkoutRequest(
        @NotBlank String name
) {
}
