package com.felipebagarelli.gymmanager.dto.response;

public record WorkoutExercisesResponse(
        Long id,
        Long exerciseId,
        Long workoutId,
        int reps,
        int sets,
        Integer position,
        Integer restSeconds,
        Double targetLoad,
        String notes) {
}
