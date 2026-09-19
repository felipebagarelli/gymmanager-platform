package com.felipebagarelli.gymmanager.exception;

import java.time.Instant;

public record ErrorResponse(
        int status,
        String message,
        Instant timestamp,
        String path
) {
}
