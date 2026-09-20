package com.felipebagarelli.gymmanager.billing.provider;

import com.stripe.exception.SignatureVerificationException;
import com.stripe.exception.StripeException;
import com.stripe.model.Account;
import com.stripe.model.AccountLink;
import com.stripe.model.Subscription;
import com.stripe.model.checkout.Session;
import com.stripe.net.RequestOptions;
import com.stripe.net.Webhook;
import com.stripe.param.AccountCreateParams;
import com.stripe.param.AccountLinkCreateParams;
import com.stripe.param.checkout.SessionCreateParams;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Adaptador da Stripe Connect (cobranca direta na conta do personal, com comissao da plataforma
 * via application_fee_percent). Nao loga dados de cliente, so o tipo de falha.
 */
public class StripePaymentProvider implements PaymentProvider {

    private static final Logger log = LoggerFactory.getLogger(StripePaymentProvider.class);

    private final String secretKey;
    private final String webhookSecret;

    public StripePaymentProvider(String secretKey, String webhookSecret) {
        this.secretKey = secretKey;
        this.webhookSecret = webhookSecret;
    }

    private RequestOptions platform() {
        return RequestOptions.builder().setApiKey(secretKey).build();
    }

    private RequestOptions onAccount(String accountId) {
        return RequestOptions.builder().setApiKey(secretKey).setStripeAccount(accountId).build();
    }

    private PaymentProviderException failure(StripeException e) {
        log.warn("Falha na Stripe: {}", e.getClass().getSimpleName());
        return new PaymentProviderException("Não foi possível concluir a operação de pagamento agora.", e);
    }

    @Override
    public String createConnectedAccount(String trainerEmail) {
        try {
            AccountCreateParams params = AccountCreateParams.builder()
                    .setType(AccountCreateParams.Type.EXPRESS)
                    .setCountry("BR")
                    .setEmail(trainerEmail)
                    .setCapabilities(AccountCreateParams.Capabilities.builder()
                            .setCardPayments(AccountCreateParams.Capabilities.CardPayments.builder().setRequested(true).build())
                            .setTransfers(AccountCreateParams.Capabilities.Transfers.builder().setRequested(true).build())
                            .build())
                    .build();
            return Account.create(params, platform()).getId();
        } catch (StripeException e) {
            throw failure(e);
        }
    }

    @Override
    public String createOnboardingLink(String accountId, String returnUrl, String refreshUrl) {
        try {
            return AccountLink.create(AccountLinkCreateParams.builder()
                    .setAccount(accountId)
                    .setReturnUrl(returnUrl)
                    .setRefreshUrl(refreshUrl)
                    .setType(AccountLinkCreateParams.Type.ACCOUNT_ONBOARDING)
                    .build(), platform()).getUrl();
        } catch (StripeException e) {
            throw failure(e);
        }
    }

    @Override
    public boolean isChargesEnabled(String accountId) {
        try {
            return Boolean.TRUE.equals(Account.retrieve(accountId, platform()).getChargesEnabled());
        } catch (StripeException e) {
            throw failure(e);
        }
    }

    @Override
    public CheckoutSession createCheckout(CheckoutRequest request) {
        try {
            String local = String.valueOf(request.localSubscriptionId());
            SessionCreateParams params = SessionCreateParams.builder()
                    .setMode(SessionCreateParams.Mode.SUBSCRIPTION)
                    .setCustomerEmail(request.studentEmail())
                    .setSuccessUrl(request.successUrl())
                    .setCancelUrl(request.cancelUrl())
                    .putMetadata("subscriptionId", local)
                    .addLineItem(SessionCreateParams.LineItem.builder()
                            .setQuantity(1L)
                            .setPriceData(SessionCreateParams.LineItem.PriceData.builder()
                                    .setCurrency("brl")
                                    .setUnitAmount((long) request.priceCents())
                                    .setRecurring(SessionCreateParams.LineItem.PriceData.Recurring.builder()
                                            .setInterval(SessionCreateParams.LineItem.PriceData.Recurring.Interval.MONTH)
                                            .build())
                                    .setProductData(SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                            .setName(request.planName())
                                            .build())
                                    .build())
                            .build())
                    .setSubscriptionData(SessionCreateParams.SubscriptionData.builder()
                            .setApplicationFeePercent(request.platformFeePercent())
                            .putMetadata("subscriptionId", local)
                            .build())
                    .build();
            Session session = Session.create(params, onAccount(request.accountId()));
            return new CheckoutSession(session.getId(), session.getUrl());
        } catch (StripeException e) {
            throw failure(e);
        }
    }

    @Override
    public void cancelSubscription(String accountId, String externalSubscriptionId) {
        try {
            Subscription.retrieve(externalSubscriptionId, onAccount(accountId)).cancel();
        } catch (StripeException e) {
            throw failure(e);
        }
    }

    @Override
    public BillingNotification parseWebhook(String payload, String signature) {
        if (webhookSecret == null || webhookSecret.isBlank()) {
            throw new PaymentUnavailableException("Os pagamentos não estão disponíveis no momento.");
        }
        try {
            Webhook.constructEvent(payload, signature, webhookSecret);
        } catch (SignatureVerificationException | RuntimeException e) {
            throw new InvalidWebhookException("Assinatura do webhook inválida.");
        }
        return StripeEventMapper.map(payload);
    }
}
