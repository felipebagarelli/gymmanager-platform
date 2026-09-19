package com.felipebagarelli.gymmanager.dto.request;


public record CreateWorkoutExerciseRequest(
        Long exerciseId,
        Long workoutId,
        int reps,
        int sets) {
}