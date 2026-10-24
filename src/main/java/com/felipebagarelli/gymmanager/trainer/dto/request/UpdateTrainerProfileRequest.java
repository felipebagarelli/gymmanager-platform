package com.felipebagarelli.gymmanager.trainer.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateTrainerProfileRequest(@NotBlank @Size(max = 120) String displayName, @Size(max = 30) String phone) {
}
