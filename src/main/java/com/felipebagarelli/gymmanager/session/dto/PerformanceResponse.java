package com.felipebagarelli.gymmanager.session.dto;

import com.felipebagarelli.gymmanager.session.entity.Effort;

public record PerformanceResponse(
        Long id,
        Long workoutExerciseId,
        int setNumber,
        int reps,
        Double loadKg,
        Effort effort
) {
}
