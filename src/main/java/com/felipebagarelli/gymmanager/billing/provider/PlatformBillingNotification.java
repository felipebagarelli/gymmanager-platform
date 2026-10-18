package com.felipebagarelli.gymmanager.billing.provider;

import java.time.LocalDateTime;

/**
 * Evento do provedor sobre o plano da plataforma, ja traduzido. {@code status} usa o vocabulario
 * do provedor normalizado: trialing, active, past_due, canceled, pending.
 */
public record PlatformBillingNotification(String eventId, Type type, Long localSubscriptionId, String externalSubscriptionId,
                                          String status, LocalDateTime periodEnd, LocalDateTime trialEnd,
                                          Boolean cancelAtPeriodEnd) {

    public enum Type {
        CHECKOUT_COMPLETED, SUBSCRIPTION_UPDATED, PAYMENT_SUCCEEDED, PAYMENT_FAILED, SUBSCRIPTION_CANCELED, IGNORED
    }
}
