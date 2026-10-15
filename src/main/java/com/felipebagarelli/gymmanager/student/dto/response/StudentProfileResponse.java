package com.felipebagarelli.gymmanager.student.dto.response;

import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;

import java.time.LocalDate;
import java.time.LocalDateTime;

public record StudentProfileResponse(
        Long id,
        String email,
        String name,
        LocalDate birthDate,
        String phone,
        String goal,
        Double height,
        Double weight,
        boolean active,
        TrainerStudentStatus status,
        Integer weeklyGoal,
        /** Início do último treino finalizado (null se nunca treinou). */
        LocalDateTime lastWorkoutAt
) {
}
