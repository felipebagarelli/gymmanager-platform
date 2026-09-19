package com.felipebagarelli.gymmanager.session.dto;

import java.time.LocalDateTime;
import java.util.List;

public record WorkoutSessionResponse(
        Long id,
        Long workoutId,
        Long studentId,
        LocalDateTime startedAt,
        LocalDateTime finishedAt,
        List<PerformanceResponse> performances
) {
}
