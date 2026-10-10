package com.felipebagarelli.gymmanager.exception;

/** Requisicao invalida por regra de negocio simples (HTTP 400). */
public class BadRequestException extends RuntimeException {
    public BadRequestException(String message) {
        super(message);
    }
}
