package com.felipebagarelli.gymmanager.billing.provider;

import java.util.Optional;

/** Usado quando nao ha chave da Stripe configurada: tudo responde 503, o app segue de pe. */
public class UnavailablePaymentProvider implements PaymentProvider {

    private static final String MESSAGE = "Os pagamentos não estão disponíveis no momento.";

    private PaymentUnavailableException unavailable() {
        return new PaymentUnavailableException(MESSAGE);
    }

    @Override
    public String createConnectedAccount(String trainerEmail) {
        throw unavailable();
    }

    @Override
    public String createOnboardingLink(String accountId, String returnUrl, String refreshUrl) {
        throw unavailable();
    }

    @Override
    public boolean isChargesEnabled(String accountId) {
        throw unavailable();
    }

    @Override
    public CheckoutSession createCheckout(CheckoutRequest request) {
        throw unavailable();
    }

    @Override
    public void cancelSubscription(String accountId, String externalSubscriptionId) {
        throw unavailable();
    }

    @Override
    public Optional<String> createRegularizationLink(String accountId, String externalSubscriptionId) {
        throw unavailable();
    }

    @Override
    public BillingNotification parseWebhook(String payload, String signature) {
        throw unavailable();
    }

    @Override
    public CheckoutSession createPlatformCheckout(PlatformCheckoutRequest request) {
        throw unavailable();
    }

    @Override
    public void setPlatformCancelAtPeriodEnd(String externalSubscriptionId, boolean cancel) {
        throw unavailable();
    }

    @Override
    public Optional<String> createPlatformRegularizationLink(String externalSubscriptionId) {
        throw unavailable();
    }

    @Override
    public PlatformBillingNotification parsePlatformWebhook(String payload, String signature) {
        throw unavailable();
    }
}
