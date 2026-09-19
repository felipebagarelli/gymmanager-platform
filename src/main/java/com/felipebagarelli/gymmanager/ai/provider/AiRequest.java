package com.felipebagarelli.gymmanager.ai.provider;

import java.util.List;

public record AiRequest(String systemPrompt, List<AiTurn> history, String question) {
}
