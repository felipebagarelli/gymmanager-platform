package com.felipebagarelli.gymmanager.billing.provider;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class StripeEventMapperTest {

    private String event(String type, String object) {
        return "{\"id\":\"evt_1\",\"type\":\"" + type + "\",\"data\":{\"object\":" + object + "}}";
    }

    @Test
    void checkoutCompleted_readsLocalIdAndSubscription() {
        BillingNotification n = StripeEventMapper.map(event("checkout.session.completed",
                "{\"subscription\":\"sub_1\",\"metadata\":{\"subscriptionId\":\"42\"}}"));

        assertThat(n.type()).isEqualTo(BillingNotification.Type.CHECKOUT_COMPLETED);
        assertThat(n.localSubscriptionId()).isEqualTo(42L);
        assertThat(n.externalSubscriptionId()).isEqualTo("sub_1");
        assertThat(n.eventId()).isEqualTo("evt_1");
    }

    @Test
    void invoicePaid_readsSubscriptionFromOldAndNewShapes_andPeriodEnd() {
        BillingNotification old = StripeEventMapper.map(event("invoice.paid",
                "{\"subscription\":\"sub_old\",\"lines\":{\"data\":[{\"period\":{\"end\":1790000000}}]}}"));
        BillingNotification recent = StripeEventMapper.map(event("invoice.paid",
                "{\"parent\":{\"subscription_details\":{\"subscription\":\"sub_new\"}}}"));

        assertThat(old.externalSubscriptionId()).isEqualTo("sub_old");
        assertThat(old.periodEnd()).isNotNull();
        assertThat(recent.externalSubscriptionId()).isEqualTo("sub_new");
        assertThat(recent.periodEnd()).isNull();
    }

    @Test
    void failedDeletedAndAccountEvents() {
        assertThat(StripeEventMapper.map(event("invoice.payment_failed", "{\"subscription\":\"sub_1\"}")).type())
                .isEqualTo(BillingNotification.Type.PAYMENT_FAILED);
        BillingNotification deleted = StripeEventMapper.map(event("customer.subscription.deleted", "{\"id\":\"sub_9\"}"));
        assertThat(deleted.type()).isEqualTo(BillingNotification.Type.SUBSCRIPTION_CANCELED);
        assertThat(deleted.externalSubscriptionId()).isEqualTo("sub_9");
        BillingNotification account = StripeEventMapper.map(event("account.updated",
                "{\"id\":\"acct_1\",\"charges_enabled\":true}"));
        assertThat(account.accountId()).isEqualTo("acct_1");
        assertThat(account.chargesEnabled()).isTrue();
    }

    @Test
    void unknownType_isIgnored() {
        assertThat(StripeEventMapper.map(event("charge.refunded", "{}")).type())
                .isEqualTo(BillingNotification.Type.IGNORED);
    }

    @Test
    void badLocalId_becomesNull() {
        BillingNotification n = StripeEventMapper.map(event("checkout.session.completed",
                "{\"subscription\":\"sub_1\",\"metadata\":{\"subscriptionId\":\"abc\"}}"));
        assertThat(n.localSubscriptionId()).isNull();
    }
}
