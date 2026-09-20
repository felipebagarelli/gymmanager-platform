package com.felipebagarelli.gymmanager.billing.provider;

import java.time.LocalDateTime;

/** Evento do provedor ja traduzido para o vocabulario do sistema. */
public record BillingNotification(String eventId, Type type, Long localSubscriptionId, String externalSubscriptionId,
                                  LocalDateTime periodEnd, String accountId, boolean chargesEnabled) {

    public enum Type {
        CHECKOUT_COMPLETED, PAYMENT_SUCCEEDED, PAYMENT_FAILED, SUBSCRIPTION_CANCELED, ACCOUNT_UPDATED, IGNORED
    }
}
