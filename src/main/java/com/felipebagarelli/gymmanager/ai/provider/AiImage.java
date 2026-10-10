package com.felipebagarelli.gymmanager.ai.provider;

/** Imagem enviada junto da pergunta (ja validada). Existe so em memoria: nunca e gravada. */
public record AiImage(String mediaType, byte[] data) {
}
