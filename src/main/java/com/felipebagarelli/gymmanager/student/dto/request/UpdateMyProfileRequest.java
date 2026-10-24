package com.felipebagarelli.gymmanager.student.dto.request;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** O que o proprio aluno pode corrigir. */
public record UpdateMyProfileRequest(
        @NotBlank @Size(max = 120) String name,
        @Size(max = 30) String phone,
        @DecimalMin("0.9") @DecimalMax("2.5") Double height,
        @DecimalMin("25") @DecimalMax("350") Double weight
) {
}
