package com.felipebagarelli.gymmanager.account.entity;

/** Documento aceito no cadastro. */
public enum LegalDocument {
    TERMS,
    PRIVACY,
    /** Consentimento especifico para dados de saude (LGPD art. 11). */
    HEALTH_DATA,
    /** Autorizacao do responsavel legal (aluno de 12 a 17 anos). */
    GUARDIAN_CONSENT
}
