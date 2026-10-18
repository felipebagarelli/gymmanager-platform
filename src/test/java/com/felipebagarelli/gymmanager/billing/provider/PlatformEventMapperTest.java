package com.felipebagarelli.gymmanager.billing.provider;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** Eventos da conta da plataforma (plano GymManager Pro). */
class PlatformEventMapperTest {

    private String event(String type, String object) {
        return "{\"id\":\"evt_p\",\"type\":\"" + type + "\",\"data\":{\"object\":" + object + "}}";
    }

    @Test
    void checkoutCompleted_readsPlatformLocalId() {
        PlatformBillingNotification n = StripeEventMapper.mapPlatform(event("checkout.session.completed",
                "{\"subscription\":\"sub_p\",\"metadata\":{\"platformSubscriptionId\":\"42\"}}"));
        assertThat(n.type()).isEqualTo(PlatformBillingNotification.Type.CHECKOUT_COMPLETED);
        assertThat(n.localSubscriptionId()).isEqualTo(42L);
        assertThat(n.externalSubscriptionId()).isEqualTo("sub_p");
    }

    @Test
    void subscriptionUpdated_readsStatusTrialAndPeriodFromOldAndNewShapes() {
        PlatformBillingNotification trial = StripeEventMapper.mapPlatform(event("customer.subscription.created",
                "{\"id\":\"sub_p\",\"status\":\"trialing\",\"trial_end\":1761000000,\"cancel_at_period_end\":false,"
                        + "\"current_period_end\":1761000000,\"metadata\":{\"platformSubscriptionId\":\"7\"}}"));
        assertThat(trial.type()).isEqualTo(PlatformBillingNotification.Type.SUBSCRIPTION_UPDATED);
        assertThat(trial.status()).isEqualTo("trialing");
        assertThat(trial.trialEnd()).isNotNull();
        assertThat(trial.periodEnd()).isNotNull();
        assertThat(trial.cancelAtPeriodEnd()).isFalse();
        assertThat(trial.localSubscriptionId()).isEqualTo(7L);

        PlatformBillingNotification recent = StripeEventMapper.mapPlatform(event("customer.subscription.updated",
                "{\"id\":\"sub_p\",\"status\":\"unpaid\",\"cancel_at_period_end\":true,"
                        + "\"items\":{\"data\":[{\"current_period_end\":1762000000}]}}"));
        assertThat(recent.status()).isEqualTo("past_due");
        assertThat(recent.periodEnd()).isNotNull();
        assertThat(recent.cancelAtPeriodEnd()).isTrue();
    }

    @Test
    void invoiceAndDeletedEvents() {
        assertThat(StripeEventMapper.mapPlatform(event("invoice.paid",
                "{\"parent\":{\"subscription_details\":{\"subscription\":\"sub_p\"}}}")).externalSubscriptionId()).isEqualTo("sub_p");
        assertThat(StripeEventMapper.mapPlatform(event("invoice.payment_failed", "{\"subscription\":\"sub_p\"}")).type())
                .isEqualTo(PlatformBillingNotification.Type.PAYMENT_FAILED);
        assertThat(StripeEventMapper.mapPlatform(event("customer.subscription.deleted", "{\"id\":\"sub_p\"}")).type())
                .isEqualTo(PlatformBillingNotification.Type.SUBSCRIPTION_CANCELED);
        assertThat(StripeEventMapper.mapPlatform(event("account.updated", "{}")).type())
                .isEqualTo(PlatformBillingNotification.Type.IGNORED);
    }

    @Test
    void normalizeStatus() {
        assertThat(StripeEventMapper.normalizeStatus("incomplete")).isEqualTo("pending");
        assertThat(StripeEventMapper.normalizeStatus("incomplete_expired")).isEqualTo("canceled");
    }
}
