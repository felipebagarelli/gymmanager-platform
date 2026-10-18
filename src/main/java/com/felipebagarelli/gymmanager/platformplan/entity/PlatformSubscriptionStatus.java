package com.felipebagarelli.gymmanager.platformplan.entity;

public enum PlatformSubscriptionStatus {
    /** Checkout criado, ainda nao concluido. */
    PENDING,
    /** Periodo de teste: ja conta como Pro. */
    TRIALING,
    ACTIVE,
    /** Cobranca falhou: perde o Pro ate regularizar. */
    PAST_DUE,
    CANCELED
}
