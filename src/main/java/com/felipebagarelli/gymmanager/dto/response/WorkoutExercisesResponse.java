package com.felipebagarelli.gymmanager.dto.response;

import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;

public record WorkoutExercisesResponse(
        Long id,
        Long exerciseId,
        Long workoutId,
        int reps,
        int sets) {
}
