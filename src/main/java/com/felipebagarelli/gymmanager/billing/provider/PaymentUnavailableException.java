package com.felipebagarelli.gymmanager.billing.provider;

public class PaymentUnavailableException extends RuntimeException {
    public PaymentUnavailableException(String message) {
        super(message);
    }
}
