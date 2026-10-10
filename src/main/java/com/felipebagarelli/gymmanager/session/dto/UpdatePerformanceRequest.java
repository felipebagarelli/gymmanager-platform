package com.felipebagarelli.gymmanager.session.dto;

import com.felipebagarelli.gymmanager.session.entity.Effort;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

public record UpdatePerformanceRequest(
        @Positive int setNumber,
        @PositiveOrZero int reps,
        @PositiveOrZero Double loadKg,
        Effort effort,
        /** true para apagar o "Como foi?" já gravado; sem isso, a falta de effort mantém o valor atual. */
        Boolean clearEffort
) {
}
