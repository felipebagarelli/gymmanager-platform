package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.AdjustmentChange;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.AdjustmentContent;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
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
 * Le os ajustes propostos pela IA e os torna seguros: so itens do plano atual, carga subindo no
 * maximo 10% (e so quando o historico permite), series mudando no maximo 1, numeros dentro dos
 * limites do nivel; troca so por exercicio do catalogo permitido, do mesmo grupo e fora do plano.
 */
public final class AdjustmentParser {

    static final double MAX_LOAD_INCREASE = 0.10;
    static final double MAX_LOAD_DECREASE = 0.30;
    static final int MAX_SWAPS = 3;
    private static final JsonMapper MAPPER = JsonMapper.builder().build();
    private static final String FAILURE = "Não consegui sugerir ajustes agora. Tente de novo em instantes.";

    private AdjustmentParser() {
    }

    public static AdjustmentContent parse(String text, Workout workout, List<WorkoutExercises> plan,
                                          Map<Long, ExerciseHistory> history, Map<String, Exercises> catalog,
                                          ProposalRules rules) {
        JsonNode root = read(text).orElseThrow(() -> new AiProviderException(FAILURE));
        if (root.path("refused").asBoolean(false)) {
            String reason = ProposalParser.clean(text(root, "reason"), ProposalParser.MAX_SUMMARY);
            throw new BadRequestException(reason.isEmpty()
                    ? "Esse pedido está fora do que o app pode ajustar. Para dor, lesão ou condição de saúde, procure um profissional."
                    : reason);
        }
        Map<Long, WorkoutExercises> byId = new java.util.HashMap<>();
        Set<Long> planExerciseIds = new HashSet<>();
        for (WorkoutExercises item : plan) {
            byId.put(item.getId(), item);
            planExerciseIds.add(item.getExercise().getId());
        }

        List<AdjustmentChange> changes = new ArrayList<>();
        Set<Long> touched = new HashSet<>();
        int swaps = 0;
        JsonNode list = root.path("changes");
        if (list.isArray()) {
            for (JsonNode node : list) {
                long id = node.path("workoutExerciseId").asLong(-1);
                WorkoutExercises item = byId.get(id);
                if (item == null || !touched.add(id)) continue;
                String action = text(node, "action").trim().toUpperCase();
                if ("SWAP".equals(action)) {
                    if (swaps >= MAX_SWAPS) continue;
                    Optional<AdjustmentChange> swap = swap(node, item, catalog, planExerciseIds, rules);
                    if (swap.isPresent()) {
                        swaps++;
                        planExerciseIds.add(swap.get().newExerciseId());
                        changes.add(swap.get());
                    }
                } else if ("PROGRESS".equals(action)) {
                    progress(node, item, history.get(id), rules).ifPresent(changes::add);
                }
            }
        }
        if (changes.isEmpty()) {
            throw new BadRequestException("Pelos seus últimos treinos, não há ajustes a sugerir agora. Continue assim!");
        }
        return new AdjustmentContent(ProposalParser.clean(text(root, "summary"), ProposalParser.MAX_SUMMARY),
                workout.getId(), workout.getName(), changes);
    }

    private static Optional<AdjustmentChange> progress(JsonNode node, WorkoutExercises item, ExerciseHistory history, ProposalRules rules) {
        String name = item.getExercise().getName() == null ? "" : item.getExercise().getName();
        int sets = clamp(node.path("sets").asInt(item.getSets()),
                Math.max(rules.minSets(), item.getSets() - 1), Math.min(rules.maxSets(), item.getSets() + 1));
        int reps = clampReps(name, node.path("reps").asInt(item.getReps()), rules);
        Integer currentRest = item.getRestSeconds();
        int rest = clamp(node.path("restSeconds").asInt(currentRest == null ? 60 : currentRest), ProposalRules.MIN_REST, ProposalRules.MAX_REST);
        Double load = load(node.path("targetLoad"), item.getTargetLoad(), history);
        boolean changed = sets != item.getSets() || reps != item.getReps()
                || (currentRest == null || rest != currentRest) || !java.util.Objects.equals(load, item.getTargetLoad());
        if (!changed) return Optional.empty();
        return Optional.of(new AdjustmentChange("PROGRESS", item.getId(), name, null, null,
                item.getSets(), item.getReps(), currentRest, item.getTargetLoad(),
                sets, reps, rest, load, ProposalParser.clean(text(node, "note"), ProposalParser.MAX_NOTE)));
    }

    /** Carga: sem historico de carga, nao inventa numero; com historico, no maximo +10% (so se pode subir). */
    static Double load(JsonNode proposed, Double current, ExerciseHistory history) {
        if (history == null || history.lastMaxLoad() == null || !proposed.isNumber()) {
            return current;
        }
        double base = history.lastMaxLoad();
        double max = history.canIncreaseLoad() ? base * (1 + MAX_LOAD_INCREASE) : base;
        double min = base * (1 - MAX_LOAD_DECREASE);
        double value = Math.max(min, Math.min(max, proposed.asDouble()));
        // arredonda para 0,5 kg (anilhas e halteres comuns)
        return Math.round(value * 2) / 2.0;
    }

    private static Optional<AdjustmentChange> swap(JsonNode node, WorkoutExercises item, Map<String, Exercises> catalog,
                                                   Set<Long> planExerciseIds, ProposalRules rules) {
        Exercises replacement = catalog.get(text(node, "newCode").trim());
        if (replacement == null || planExerciseIds.contains(replacement.getId())) return Optional.empty();
        String group = item.getExercise().getMuscleGroup();
        // troca so dentro do mesmo grupo muscular (o treino continua equilibrado)
        if (group == null || replacement.getMuscleGroup() == null || !group.equalsIgnoreCase(replacement.getMuscleGroup())) {
            return Optional.empty();
        }
        String name = replacement.getName() == null ? "" : replacement.getName();
        int sets = clamp(node.path("sets").asInt(item.getSets()), rules.minSets(), rules.maxSets());
        int reps = clampReps(name, node.path("reps").asInt(item.getReps()), rules);
        Integer currentRest = item.getRestSeconds();
        int rest = clamp(node.path("restSeconds").asInt(currentRest == null ? 60 : currentRest), ProposalRules.MIN_REST, ProposalRules.MAX_REST);
        return Optional.of(new AdjustmentChange("SWAP", item.getId(), item.getExercise().getName(),
                replacement.getId(), name, item.getSets(), item.getReps(), currentRest, item.getTargetLoad(),
                sets, reps, rest, null, ProposalParser.clean(text(node, "note"), ProposalParser.MAX_NOTE)));
    }

    private static int clampReps(String name, int value, ProposalRules rules) {
        if (name.contains("(segundos)")) return clamp(value, ProposalRules.MIN_SECONDS, ProposalRules.MAX_SECONDS);
        if (name.contains("(minutos)")) return clamp(value, ProposalRules.MIN_MINUTES, ProposalRules.MAX_MINUTES);
        return clamp(value, rules.minReps(), rules.maxReps());
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private static Optional<JsonNode> read(String text) {
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

    public static String toJson(AdjustmentContent content) {
        return MAPPER.writeValueAsString(content);
    }

    public static AdjustmentContent fromJson(String json) {
        return MAPPER.readValue(json, AdjustmentContent.class);
    }
}
