package com.felipebagarelli.gymmanager.ai.provider;

import com.felipebagarelli.gymmanager.ai.entity.AiRole;

/** Uma fala anterior da conversa, enviada ao modelo como historico. */
public record AiTurn(AiRole role, String text) {
}
