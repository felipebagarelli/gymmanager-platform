package com.felipebagarelli.gymmanager.ai.provider;

import java.util.List;

/** {@code maxTokens} nulo = o limite padrao do provedor (respostas maiores, como propostas de treino, pedem mais). */
public record AiRequest(String systemPrompt, List<AiTurn> history, String question, AiImage image, Long maxTokens) {

    /** Pergunta so de texto. */
    public AiRequest(String systemPrompt, List<AiTurn> history, String question) {
        this(systemPrompt, history, question, null, null);
    }

    public AiRequest(String systemPrompt, List<AiTurn> history, String question, AiImage image) {
        this(systemPrompt, history, question, image, null);
    }
}
