package com.felipebagarelli.gymmanager.student.dto.request;

import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import jakarta.validation.constraints.NotNull;

/** Pausar (PAUSED) ou retomar (ACTIVE) o vinculo do aluno com o personal. */
public record UpdateLinkStatusRequest(
        @NotNull TrainerStudentStatus status
) {
}
