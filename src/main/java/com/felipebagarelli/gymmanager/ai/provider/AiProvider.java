package com.felipebagarelli.gymmanager.ai.provider;

/**
 * Porta do modulo de IA: o dominio nao conhece o provedor. Trocar de modelo/fornecedor
 * e implementar esta interface e registra-la em AiConfig.
 */
public interface AiProvider {

    AiReply ask(AiRequest request);
}
