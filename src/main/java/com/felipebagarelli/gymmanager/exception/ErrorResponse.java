package com.felipebagarelli.gymmanager.exception;

import java.time.Instant;

public record ErrorResponse(
        int status,
        String message,
        Instant timestamp,
        String path,
        /* motivo legivel por maquina, quando o app precisa reagir (ex.: EMAIL_NOT_VERIFIED) */
        String code
) {
    public ErrorResponse(int status, String message, Instant timestamp, String path) {
        this(status, message, timestamp, path, null);
    }
}
