package com.felipebagarelli.gymmanager.billing.provider;

public class InvalidWebhookException extends RuntimeException {
    public InvalidWebhookException(String message) {
        super(message);
    }
}
