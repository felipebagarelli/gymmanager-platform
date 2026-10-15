package com.felipebagarelli.gymmanager.dto.response;

import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;

import java.time.LocalDateTime;

public record WorkoutAssignmentResponse(
        Long id,
        Long workoutId,
        Long studentId,
        WorkoutAssignmentStatus status,
        LocalDateTime startedAt,
        LocalDateTime endedAt,
        String studentName
) {
}
