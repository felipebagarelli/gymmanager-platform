package com.felipebagarelli.gymmanager.dto.response;

import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;

import java.time.LocalDateTime;
import java.util.List;

public record WorkoutAssignmentResponse(
        Long id,
        Long workoutId,
        Long studentId,
        WorkoutAssignmentStatus status,
        LocalDateTime startedAt,
        LocalDateTime endedAt,
        String studentName,
        /* dias da semana (1 = segunda ... 7 = domingo); vazio = sem dia marcado */
        List<Integer> weekdays
) {
}
