package com.felipebagarelli.gymmanager.account.entity;

/** Para que serve um codigo/link enviado por e-mail. */
public enum TokenPurpose {
    /** Codigo de 6 digitos para confirmar o e-mail do cadastro. */
    VERIFY_EMAIL,
    /** Codigo de 6 digitos para trocar a senha esquecida. */
    RESET_PASSWORD,
    /** Link enviado ao responsavel legal do aluno de 12 a 17 anos. */
    GUARDIAN_CONSENT
}
