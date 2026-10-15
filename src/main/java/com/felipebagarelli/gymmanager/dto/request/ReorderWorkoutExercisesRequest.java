package com.felipebagarelli.gymmanager.dto.request;

import jakarta.validation.constraints.NotNull;

import java.util.List;

/** Nova ordem do plano: todos os exercicios atuais do treino, na ordem desejada. */
public record ReorderWorkoutExercisesRequest(
        @NotNull List<Long> workoutExerciseIds
) {
}
