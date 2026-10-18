package com.felipebagarelli.gymmanager.platformplan.dto;

import com.felipebagarelli.gymmanager.platformplan.entity.BillingInterval;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscriptionStatus;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDateTime;

public final class PlatformPlanDtos {

    private PlatformPlanDtos() {
    }

    public enum Tier { FREE, PRO }

    /** Precos e teste vigentes (definidos no servidor). */
    public record Offer(int monthlyCents, int yearlyCents, int trialDays, boolean trialAvailable) {
    }

    public record SubscriptionInfo(PlatformSubscriptionStatus status, BillingInterval interval, int priceCents,
                                   LocalDateTime currentPeriodEnd, LocalDateTime trialEnd, boolean cancelAtPeriodEnd) {
    }

    /**
     * Situacao do aluno: plano atual, assinatura (se houver), oferta e o que cada plano libera.
     * {@code aiWorkoutsPerMonth} nulo = sem limite. {@code canSubscribe} falso traz o motivo.
     */
    public record PlatformPlanResponse(Tier tier, SubscriptionInfo subscription, Offer offer,
                                       Integer aiWorkoutsPerMonth, boolean canSubscribe, String unavailableReason) {
    }

    public record SubscribeRequest(@NotNull BillingInterval interval) {
    }
}
