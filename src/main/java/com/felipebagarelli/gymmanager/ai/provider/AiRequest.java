package com.felipebagarelli.gymmanager.ai.provider;

import java.util.List;

public record AiRequest(String systemPrompt, List<AiTurn> history, String question, AiImage image) {

    /** Pergunta so de texto. */
    public AiRequest(String systemPrompt, List<AiTurn> history, String question) {
        this(systemPrompt, history, question, null);
    }
}
