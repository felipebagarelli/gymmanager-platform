package com.felipebagarelli.gymmanager.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

public record CreateWorkoutExerciseRequest(
        @NotNull Long exerciseId,
        @NotNull Long workoutId,
        @Positive int reps,
        @Positive int sets,
        @Positive Integer position,
        @PositiveOrZero Integer restSeconds,
        @PositiveOrZero Double targetLoad,
        String notes) {
}
