package com.felipebagarelli.gymmanager.exception;

/** Imagem enviada ao assistente invalida (tipo nao suportado, vazia, corrompida ou grande demais). */
public class InvalidImageException extends RuntimeException {
    public InvalidImageException(String message) {
        super(message);
    }
}
