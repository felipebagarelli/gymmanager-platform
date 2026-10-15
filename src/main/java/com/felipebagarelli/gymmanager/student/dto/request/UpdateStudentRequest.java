package com.felipebagarelli.gymmanager.student.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;

import java.time.LocalDate;

public record UpdateStudentRequest(
        @NotBlank String name,
        LocalDate birthDate,
        String phone,
        String goal,
        @Positive Double height,
        @Positive Double weight,
        @Min(1) @Max(14) Integer weeklyGoal,
        /** true para remover a meta; sem isso, a falta de weeklyGoal mantém a meta atual. */
        Boolean clearWeeklyGoal
) {
}
