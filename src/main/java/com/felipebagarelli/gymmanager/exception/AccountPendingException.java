package com.felipebagarelli.gymmanager.exception;

/** Senha certa, mas a conta ainda nao pode entrar (e-mail nao confirmado, responsavel nao autorizou). HTTP 403. */
public class AccountPendingException extends RuntimeException {

    public static final String EMAIL_NOT_VERIFIED = "EMAIL_NOT_VERIFIED";
    public static final String GUARDIAN_CONSENT_PENDING = "GUARDIAN_CONSENT_PENDING";

    private final String code;

    public AccountPendingException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String code() {
        return code;
    }
}
