package com.felipebagarelli.gymmanager.session.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

public record RecordPerformanceRequest(
        @NotNull Long workoutExerciseId,
        @Positive int setNumber,
        @PositiveOrZero int reps,
        @PositiveOrZero Double loadKg
) {
}
