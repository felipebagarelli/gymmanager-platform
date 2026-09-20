package com.felipebagarelli.gymmanager.billing.provider;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class BillingConfig {

    @Bean
    public PaymentProvider paymentProvider(@Value("${app.billing.stripe-secret-key:}") String secretKey,
                                           @Value("${app.billing.stripe-webhook-secret:}") String webhookSecret) {
        if (secretKey == null || secretKey.isBlank()) {
            return new UnavailablePaymentProvider();
        }
        return new StripePaymentProvider(secretKey, webhookSecret);
    }
}
