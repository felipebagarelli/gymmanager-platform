package com.felipebagarelli.gymmanager.exception;

/** Acesso bloqueado por mensalidade em atraso (HTTP 402). */
public class PaymentRequiredException extends RuntimeException {
    public PaymentRequiredException(String message) {
        super(message);
    }
}
