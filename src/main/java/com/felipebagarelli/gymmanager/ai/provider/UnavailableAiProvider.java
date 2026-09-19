package com.felipebagarelli.gymmanager.ai.provider;

/** Usado quando nao ha chave configurada: o app sobe e o assistente responde 503. */
public class UnavailableAiProvider implements AiProvider {

    @Override
    public AiReply ask(AiRequest request) {
        throw new AiUnavailableException("O assistente não está disponível no momento.");
    }
}
