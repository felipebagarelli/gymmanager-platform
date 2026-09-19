package com.felipebagarelli.gymmanager.session.dto;

import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

public record UpdatePerformanceRequest(
        @Positive int setNumber,
        @PositiveOrZero int reps,
        @PositiveOrZero Double loadKg
) {
}
