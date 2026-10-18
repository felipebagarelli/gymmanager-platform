package com.felipebagarelli.gymmanager.aiworkout.entity;

public enum ProposalStatus {
    /** Aguardando o aluno decidir. */
    PROPOSED,
    /** Aceita: os treinos foram criados. */
    ACCEPTED,
    REJECTED,
    /** Passou do prazo sem decisao. */
    EXPIRED
}
