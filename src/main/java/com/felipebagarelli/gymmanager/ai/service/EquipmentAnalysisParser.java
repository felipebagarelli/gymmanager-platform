package com.felipebagarelli.gymmanager.ai.service;

import com.felipebagarelli.gymmanager.ai.dto.EquipmentAnalysis;
import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Le a resposta JSON do modelo na analise de foto, valida e normaliza (limites de tamanho) antes de
 * gravar ou devolver ao app. Resposta fora do formato vira erro do provedor: nada e gravado.
 */
public final class EquipmentAnalysisParser {

    static final int MAX_NAME = 80;
    static final int MAX_ITEMS = 8;
    static final int MAX_ITEM_LENGTH = 300;
    private static final JsonMapper MAPPER = JsonMapper.builder().build();
    private static final String FAILURE = "Não consegui analisar a foto. Tente outra foto, mais de perto e com boa luz.";

    private EquipmentAnalysisParser() {
    }

    /** Texto do modelo (pode vir com cerca de markdown ou texto em volta) -> analise normalizada. */
    public static EquipmentAnalysis parseModelOutput(String text) {
        JsonNode root;
        try {
            int start = text.indexOf('{');
            int end = text.lastIndexOf('}');
            if (start < 0 || end <= start) throw new IllegalArgumentException("sem objeto JSON");
            root = MAPPER.readTree(text.substring(start, end + 1));
        } catch (RuntimeException e) {
            throw new AiProviderException(FAILURE);
        }
        boolean inPlan = root.path("noPlano").asBoolean(false);
        String name = clean(text(root, "equipamento"), MAX_NAME);
        boolean recognized = root.path("reconhecido").asBoolean(!name.isEmpty());
        if (!recognized) {
            return new EquipmentAnalysis(false, "", List.of(), List.of(), List.of(), false);
        }
        List<String> steps = list(root.path("passos"));
        if (name.isEmpty() || steps.isEmpty()) {
            throw new AiProviderException(FAILURE);
        }
        return new EquipmentAnalysis(true, name, list(root.path("musculos")), list(root.path("preparacao")), steps, inPlan);
    }

    public static String toStoredJson(EquipmentAnalysis analysis) {
        return MAPPER.writeValueAsString(analysis);
    }

    /** Le o JSON gravado; vazio se estiver ilegivel (a mensagem aparece como texto simples). */
    public static Optional<EquipmentAnalysis> fromStored(String body) {
        try {
            return Optional.of(MAPPER.readValue(body, EquipmentAnalysis.class));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    /** Resumo curto para o historico enviado ao modelo nas perguntas seguintes. */
    public static String summary(EquipmentAnalysis analysis) {
        if (!analysis.recognized()) return "Não reconheci o aparelho da foto.";
        String muscles = analysis.muscles().isEmpty() ? "" : " Trabalha: " + String.join(", ", analysis.muscles()) + ".";
        return "Aparelho identificado: " + analysis.name() + "." + muscles;
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node.path(field);
        return value.isString() ? value.asString() : "";
    }

    private static List<String> list(JsonNode array) {
        List<String> out = new ArrayList<>();
        if (!array.isArray()) return out;
        for (JsonNode item : array) {
            String value = item.isString() ? clean(item.asString(), MAX_ITEM_LENGTH) : "";
            if (!value.isEmpty() && out.size() < MAX_ITEMS) out.add(value);
        }
        return out;
    }

    private static String clean(String text, int max) {
        String flat = text == null ? "" : text.replaceAll("[\\r\\n\\t]+", " ").replaceAll("\\s{2,}", " ").trim();
        return flat.length() > max ? flat.substring(0, max) + "…" : flat;
    }
}
