package com.felipebagarelli.gymmanager.billing.provider;

import java.util.Optional;

/** Porta do provedor de pagamentos: o resto do sistema nao conhece a Stripe. */
public interface PaymentProvider {

    /** Cria a conta que recebe os pagamentos do personal; devolve o id externo. */
    String createConnectedAccount(String trainerEmail);

    /** Link para o personal concluir o cadastro (dados bancarios/identidade) no provedor. */
    String createOnboardingLink(String accountId, String returnUrl, String refreshUrl);

    boolean isChargesEnabled(String accountId);

    CheckoutSession createCheckout(CheckoutRequest request);

    void cancelSubscription(String accountId, String externalSubscriptionId);

    /**
     * Link do provedor para o aluno quitar a cobranca em aberto de uma assinatura em atraso.
     * Vazio quando nao ha cobranca em aberto (ex.: o provedor ainda nao registrou a falha).
     */
    Optional<String> createRegularizationLink(String accountId, String externalSubscriptionId);

    /** Valida a assinatura do webhook e o converte em notificacao de dominio. */
    BillingNotification parseWebhook(String payload, String signature);

    // ---- plano da plataforma (conta da propria plataforma, sem Connect)

    CheckoutSession createPlatformCheckout(PlatformCheckoutRequest request);

    /** Cancelar no fim do periodo (true) ou desfazer o cancelamento (false). */
    void setPlatformCancelAtPeriodEnd(String externalSubscriptionId, boolean cancel);

    /** Cancela o Pro na hora (exclusao da conta). */
    void cancelPlatformSubscription(String externalSubscriptionId);

    /** Fatura em aberto do plano da plataforma (assinatura em atraso). */
    Optional<String> createPlatformRegularizationLink(String externalSubscriptionId);

    /** Webhook do endpoint da conta da plataforma (segredo proprio). */
    PlatformBillingNotification parsePlatformWebhook(String payload, String signature);
}
