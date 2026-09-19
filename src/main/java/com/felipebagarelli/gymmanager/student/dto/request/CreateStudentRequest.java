package com.felipebagarelli.gymmanager.student.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record CreateStudentRequest(
        @NotBlank @Email String email,
        @NotBlank @Size(min = 8) String password,
        @NotBlank String name,
        LocalDate birthDate,
        String phone,
        String goal,
        @Positive Double height,
        @Positive Double weight
) {
}
