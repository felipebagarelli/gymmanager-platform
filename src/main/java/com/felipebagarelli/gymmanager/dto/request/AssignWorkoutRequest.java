package com.felipebagarelli.gymmanager.dto.request;

import jakarta.validation.constraints.NotNull;

public record AssignWorkoutRequest(
        @NotNull Long studentId
) {
}
