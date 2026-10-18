package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposalContent;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposedExercise;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposedWorkout;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * Le a resposta da IA e a transforma numa proposta segura. Nada da resposta e confiado: so entram
 * exercicios do catalogo permitido (pelo codigo), numeros fora dos limites sao trazidos para dentro,
 * textos sao cortados e limpos. Resposta inutilizavel vira erro (nada e gravado).
 */
public final class ProposalParser {

    static final int MAX_NAME = 40;
    static final int MAX_FOCUS = 60;
    static final int MAX_NOTE = 120;
    static final int MAX_SUMMARY = 300;
    private static final JsonMapper MAPPER = JsonMapper.builder().build();
    private static final String FAILURE = "Não consegui montar uma proposta agora. Tente de novo em instantes.";
    private static final String[] LETTERS = {"A", "B", "C", "D", "E"};

    private ProposalParser() {
    }

    /**
     * @param catalog exercicios permitidos para este aluno, pelo codigo
     * @throws BadRequestException quando a IA recusa o pedido (fora do escopo), com o motivo
     * @throws AiProviderException quando a resposta nao serve
     */
    public static ProposalContent parse(String text, Map<String, Exercises> catalog, ProposalRules rules) {
        JsonNode root = readJson(text).orElseThrow(() -> new AiProviderException(FAILURE));
        if (root.path("refused").asBoolean(false)) {
            String reason = clean(text(root, "reason"), MAX_SUMMARY);
            throw new BadRequestException(reason.isEmpty()
                    ? "Esse pedido está fora do que o app pode montar. Para dor, lesão ou condição de saúde, procure um profissional."
                    : reason);
        }
        List<ProposedWorkout> workouts = new ArrayList<>();
        JsonNode list = root.path("workouts");
        if (list.isArray()) {
            for (JsonNode node : list) {
                if (workouts.size() >= rules.maxWorkouts()) break;
                workout(node, workouts.size(), catalog, rules).ifPresent(workouts::add);
            }
        }
        if (workouts.isEmpty()) {
            throw new AiProviderException(FAILURE);
        }
        return new ProposalContent(clean(text(root, "summary"), MAX_SUMMARY), workouts);
    }

    private static Optional<ProposedWorkout> workout(JsonNode node, int index, Map<String, Exercises> catalog, ProposalRules rules) {
        List<ProposedExercise> exercises = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        JsonNode items = node.path("exercises");
        if (items.isArray()) {
            for (JsonNode item : items) {
                if (exercises.size() >= rules.maxExercises()) break;
                String code = text(item, "code").trim();
                Exercises exercise = catalog.get(code);
                // fora do catalogo permitido (inventado ou de equipamento que o aluno nao tem): descarta
                if (exercise == null || !seen.add(code)) continue;
                exercises.add(exercise(item, exercise, rules));
            }
        }
        if (exercises.size() < rules.minExercises()) {
            return Optional.empty();
        }
        String letter = LETTERS[Math.min(index, LETTERS.length - 1)];
        String focus = clean(text(node, "focus"), MAX_FOCUS);
        String name = "Treino " + letter + (focus.isEmpty() ? "" : " - " + focus);
        return Optional.of(new ProposedWorkout(clean(name, MAX_NAME + MAX_FOCUS), focus, exercises));
    }

    private static ProposedExercise exercise(JsonNode item, Exercises exercise, ProposalRules rules) {
        String name = exercise.getName() == null ? "" : exercise.getName();
        int reps;
        if (name.contains("(segundos)")) {
            reps = clamp(item.path("reps").asInt(30), ProposalRules.MIN_SECONDS, ProposalRules.MAX_SECONDS);
        } else if (name.contains("(minutos)")) {
            reps = clamp(item.path("reps").asInt(10), ProposalRules.MIN_MINUTES, ProposalRules.MAX_MINUTES);
        } else {
            reps = clamp(item.path("reps").asInt(rules.minReps()), rules.minReps(), rules.maxReps());
        }
        int sets = clamp(item.path("sets").asInt(rules.minSets()), rules.minSets(), rules.maxSets());
        int rest = clamp(item.path("restSeconds").asInt(60), ProposalRules.MIN_REST, ProposalRules.MAX_REST);
        String equipment = exercise.getEquipment() == null ? null : exercise.getEquipment().name();
        return new ProposedExercise(exercise.getId(), exercise.getCatalogCode(), name, exercise.getMuscleGroup(), equipment,
                sets, reps, rest, clean(text(item, "note"), MAX_NOTE));
    }

    static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private static Optional<JsonNode> readJson(String text) {
        if (text == null) return Optional.empty();
        int start = text.indexOf('{');
        int end = text.lastIndexOf('}');
        if (start < 0 || end <= start) return Optional.empty();
        try {
            return Optional.of(MAPPER.readTree(text.substring(start, end + 1)));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node.path(field);
        return value.isString() ? value.asString() : "";
    }

    /** Sem quebras, sem caracteres de controle, sem links; cortado no limite. */
    static String clean(String value, int max) {
        if (value == null) return "";
        String s = value.replaceAll("\\p{Cntrl}", " ").replaceAll("(?i)https?://\\S+", "").replaceAll("\\s+", " ").trim();
        return s.length() > max ? s.substring(0, max).trim() : s;
    }

    public static String toJson(ProposalContent content) {
        return MAPPER.writeValueAsString(content);
    }

    public static ProposalContent fromJson(String json) {
        return MAPPER.readValue(json, ProposalContent.class);
    }
}
