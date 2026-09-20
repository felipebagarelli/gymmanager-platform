package com.felipebagarelli.gymmanager.billing.entity;

public enum SubscriptionStatus {
    /** Checkout criado, ainda nao pago. */
    PENDING,
    ACTIVE,
    /** Cobranca falhou: treinos e chat do aluno ficam bloqueados. */
    PAST_DUE,
    CANCELED
}
