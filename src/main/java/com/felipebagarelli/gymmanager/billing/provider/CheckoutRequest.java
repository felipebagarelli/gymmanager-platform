package com.felipebagarelli.gymmanager.billing.provider;

import java.math.BigDecimal;

public record CheckoutRequest(String accountId, String studentEmail, String planName, int priceCents,
                              BigDecimal platformFeePercent, long localSubscriptionId,
                              String successUrl, String cancelUrl) {
}
