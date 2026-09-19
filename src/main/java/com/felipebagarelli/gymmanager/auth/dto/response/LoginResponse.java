package com.felipebagarelli.gymmanager.auth.dto.response;

public record LoginResponse(
        String token,
        long expiresInSeconds,
        String role
) {
}
