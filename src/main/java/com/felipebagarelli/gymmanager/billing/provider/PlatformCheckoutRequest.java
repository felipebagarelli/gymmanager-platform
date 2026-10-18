package com.felipebagarelli.gymmanager.billing.provider;

/**
 * Checkout do plano da plataforma: assinatura na conta da propria plataforma (sem Connect).
 * {@code yearly} define a recorrencia; {@code trialDays} 0 = sem teste.
 */
public record PlatformCheckoutRequest(String customerEmail, String productName, int priceCents, boolean yearly,
                                      int trialDays, long localSubscriptionId, String successUrl, String cancelUrl) {
}
