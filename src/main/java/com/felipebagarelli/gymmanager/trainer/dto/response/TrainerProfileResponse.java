package com.felipebagarelli.gymmanager.trainer.dto.response;

public record TrainerProfileResponse(
        Long id,
        String email,
        String displayName,
        String phone
) {
}
