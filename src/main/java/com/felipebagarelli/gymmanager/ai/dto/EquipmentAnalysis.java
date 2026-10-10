package com.felipebagarelli.gymmanager.ai.dto;

import java.util.List;

/**
 * Resposta estruturada da analise de foto de aparelho. Quando o aparelho nao e reconhecido,
 * recognized e false e o restante vem vazio (a IA nao deve chutar).
 */
public record EquipmentAnalysis(
        boolean recognized,
        String name,
        List<String> muscles,
        List<String> setup,
        List<String> steps,
        boolean inPlan
) {
}
