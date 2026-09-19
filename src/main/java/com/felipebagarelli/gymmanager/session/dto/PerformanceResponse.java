package com.felipebagarelli.gymmanager.session.dto;

public record PerformanceResponse(
        Long id,
        Long workoutExerciseId,
        int setNumber,
        int reps,
        Double loadKg
) {
}
