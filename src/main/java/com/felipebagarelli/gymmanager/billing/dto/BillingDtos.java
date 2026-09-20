package com.felipebagarelli.gymmanager.billing.dto;

import com.felipebagarelli.gymmanager.billing.entity.SubscriptionStatus;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

/** DTOs do modulo de cobranca (precos sempre em centavos de real). */
public final class BillingDtos {

    private BillingDtos() {
    }

    public record PlanRequest(@NotBlank @Size(max = 100) String name,
                              @Size(max = 1000) String description,
                              @Min(100) @Max(10_000_000) int priceCents,
                              Boolean active) {
    }

    public record PlanResponse(Long id, String name, String description, int priceCents, boolean active) {
    }

    public record SubscribeRequest(@NotNull Long planId) {
    }

    public record UrlResponse(String url) {
    }

    public record PayoutAccountResponse(boolean connected, boolean chargesEnabled) {
    }

    public record SubscriptionResponse(Long id, SubscriptionStatus status, Long planId, String planName,
                                       int priceCents, LocalDateTime currentPeriodEnd,
                                       Long studentId, String studentName) {
    }
}
