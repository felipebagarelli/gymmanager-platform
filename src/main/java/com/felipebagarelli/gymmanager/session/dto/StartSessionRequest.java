package com.felipebagarelli.gymmanager.session.dto;

import jakarta.validation.constraints.NotNull;

public record StartSessionRequest(@NotNull Long workoutId) {
}
