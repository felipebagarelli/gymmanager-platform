package com.felipebagarelli.gymmanager.dto.request;

import jakarta.validation.constraints.NotNull;

import java.util.List;

public record AssignWorkoutRequest(
        @NotNull Long studentId,
        /* dias da semana (1 = segunda ... 7 = domingo); vazio ou nulo = sem dia marcado */
        List<Integer> weekdays
) {
}
