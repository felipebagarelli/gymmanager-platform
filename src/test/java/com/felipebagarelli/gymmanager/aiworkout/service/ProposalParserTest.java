package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposalContent;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposedExercise;
import com.felipebagarelli.gymmanager.entity.ExerciseEquipment;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingGoal;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLevel;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLocation;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** D2/D6: a resposta da IA nunca e confiada; o servidor valida e corrige. */
class ProposalParserTest {

    private static Exercises ex(long id, String code, String name, String group, ExerciseEquipment eq) {
        return Exercises.builder().id(id).catalogCode(code).name(name).muscleGroup(group).equipment(eq).build();
    }

    private final Map<String, Exercises> catalog = new LinkedHashMap<>();

    {
        catalog.put("agachamento_goblet", ex(1, "agachamento_goblet", "Agachamento goblet", "Pernas", ExerciseEquipment.DUMBBELL));
        catalog.put("flexao_de_braco", ex(2, "flexao_de_braco", "Flexão de braço", "Peito", ExerciseEquipment.BODYWEIGHT));
        catalog.put("remada_unilateral_com_halter", ex(3, "remada_unilateral_com_halter", "Remada unilateral com halter", "Costas", ExerciseEquipment.DUMBBELL));
        catalog.put("prancha_segundos", ex(4, "prancha_segundos", "Prancha (segundos)", "Abdômen", ExerciseEquipment.BODYWEIGHT));
        catalog.put("afundo_com_peso_do_corpo", ex(5, "afundo_com_peso_do_corpo", "Afundo com peso do corpo", "Pernas", ExerciseEquipment.BODYWEIGHT));
    }

    private static ProposalRules beginner(int days, int minutes) {
        return ProposalRules.of(TrainingProfile.builder().goal(TrainingGoal.HEALTH).level(TrainingLevel.BEGINNER)
                .daysPerWeek(days).minutesPerSession(minutes).location(TrainingLocation.HOME).equipment("DUMBBELLS").build());
    }

    @Test
    void validProposal_isNormalized_andClampedToTheLimits() {
        String json = """
                Aqui está: {"refused": false, "summary": "Corpo inteiro 2x.", "workouts": [
                  {"focus": "Corpo inteiro", "exercises": [
                    {"code": "agachamento_goblet", "sets": 9, "reps": 40, "restSeconds": 5, "note": "Desça devagar"},
                    {"code": "flexao_de_braco", "sets": 3, "reps": 10, "restSeconds": 60},
                    {"code": "prancha_segundos", "sets": 2, "reps": 600, "restSeconds": 45},
                    {"code": "remada_unilateral_com_halter", "sets": 3, "reps": 12, "restSeconds": 400}
                  ]}
                ]}
                """;
        ProposalContent content = ProposalParser.parse(json, catalog, beginner(3, 45));

        assertThat(content.summary()).isEqualTo("Corpo inteiro 2x.");
        assertThat(content.workouts()).singleElement().satisfies(w -> {
            assertThat(w.name()).isEqualTo("Treino A - Corpo inteiro");
            ProposedExercise goblet = w.exercises().get(0);
            assertThat(goblet.sets()).isEqualTo(3);          // iniciante: no maximo 3 series
            assertThat(goblet.reps()).isEqualTo(15);         // ate 15 repeticoes
            assertThat(goblet.restSeconds()).isEqualTo(30);  // descanso minimo
            assertThat(goblet.exerciseId()).isEqualTo(1L);
            assertThat(w.exercises().get(2).reps()).isEqualTo(60);  // prancha: segundos, no maximo 60
            assertThat(w.exercises().get(3).restSeconds()).isEqualTo(180);
        });
    }

    @Test
    void inventedOrForbiddenExercises_areDropped_andDuplicatesToo() {
        String json = """
                {"workouts": [{"focus": "Superiores", "exercises": [
                  {"code": "supino_reto_com_barra", "sets": 3, "reps": 10},
                  {"code": "exercicio_inventado", "sets": 3, "reps": 10},
                  {"code": "flexao_de_braco", "sets": 3, "reps": 10},
                  {"code": "flexao_de_braco", "sets": 3, "reps": 10},
                  {"code": "remada_unilateral_com_halter", "sets": 3, "reps": 10},
                  {"code": "prancha_segundos", "sets": 3, "reps": 30}
                ]}]}
                """;
        ProposalContent content = ProposalParser.parse(json, catalog, beginner(3, 45));

        assertThat(content.workouts().getFirst().exercises()).extracting(ProposedExercise::code)
                .containsExactly("flexao_de_braco", "remada_unilateral_com_halter", "prancha_segundos");
    }

    @Test
    void workoutWithTooFewValidExercises_isDropped_andNothingLeftIsAFailure() {
        String json = """
                {"workouts": [{"focus": "X", "exercises": [{"code": "flexao_de_braco", "sets": 3, "reps": 10}]}]}
                """;
        assertThatThrownBy(() -> ProposalParser.parse(json, catalog, beginner(3, 45))).isInstanceOf(AiProviderException.class);
        assertThatThrownBy(() -> ProposalParser.parse("não é json", catalog, beginner(3, 45))).isInstanceOf(AiProviderException.class);
    }

    @Test
    void moreWorkoutsThanDays_andMoreExercisesThanTime_areCut() {
        StringBuilder workouts = new StringBuilder();
        for (int i = 0; i < 4; i++) {
            if (i > 0) workouts.append(',');
            workouts.append("""
                    {"focus": "F%d", "exercises": [
                      {"code": "agachamento_goblet"}, {"code": "flexao_de_braco"}, {"code": "remada_unilateral_com_halter"},
                      {"code": "prancha_segundos"}, {"code": "afundo_com_peso_do_corpo"}
                    ]}""".formatted(i));
        }
        // 2 dias e 30 minutos: no maximo 2 treinos e 3 exercicios
        ProposalContent content = ProposalParser.parse("{\"workouts\": [" + workouts + "]}", catalog, beginner(2, 30));
        assertThat(content.workouts()).hasSize(2);
        assertThat(content.workouts()).allSatisfy(w -> assertThat(w.exercises()).hasSize(3));
        assertThat(content.workouts().get(1).name()).startsWith("Treino B");
    }

    @Test
    void refusal_becomesAFriendlyBadRequest() {
        assertThatThrownBy(() -> ProposalParser.parse(
                "{\"refused\": true, \"reason\": \"Para dor no joelho, procure um fisioterapeuta.\"}", catalog, beginner(3, 45)))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("fisioterapeuta");
    }

    @Test
    void texts_areCleaned_noLinksNoControlCharsAndCut() {
        String note = "Veja https://site-suspeito.test/x agora\\u0007 " + "a".repeat(300);
        String json = """
                {"summary": "%s", "workouts": [{"focus": "Corpo inteiro", "exercises": [
                  {"code": "agachamento_goblet", "note": "%s"}, {"code": "flexao_de_braco"}, {"code": "remada_unilateral_com_halter"}
                ]}]}
                """.formatted(note, note);
        ProposalContent content = ProposalParser.parse(json, catalog, beginner(3, 45));
        String cleaned = content.workouts().getFirst().exercises().getFirst().note();
        assertThat(cleaned).doesNotContain("http").hasSizeLessThanOrEqualTo(ProposalParser.MAX_NOTE);
        assertThat(content.summary()).doesNotContain("http").hasSizeLessThanOrEqualTo(ProposalParser.MAX_SUMMARY);
    }

    @Test
    void rules_byLevelTimeAndEquipment() {
        ProposalRules home = ProposalRules.of(TrainingProfile.builder().level(TrainingLevel.ADVANCED).daysPerWeek(7)
                .minutesPerSession(90).location(TrainingLocation.HOME).equipment("BANDS,PULL_UP_BAR,BENCH").build());
        assertThat(home.maxWorkouts()).isEqualTo(5);
        assertThat(home.maxExercises()).isEqualTo(8);
        assertThat(home.maxSets()).isEqualTo(5);
        assertThat(home.equipment()).containsExactlyInAnyOrder(ExerciseEquipment.BODYWEIGHT, ExerciseEquipment.BAND, ExerciseEquipment.PULL_UP_BAR);

        ProposalRules body = ProposalRules.of(TrainingProfile.builder().level(TrainingLevel.BEGINNER).daysPerWeek(1)
                .minutesPerSession(15).location(TrainingLocation.BODYWEIGHT).build());
        assertThat(body.equipment()).containsExactly(ExerciseEquipment.BODYWEIGHT);
        assertThat(body.maxExercises()).isEqualTo(3);
        assertThat(body.maxWorkouts()).isEqualTo(1);

        ProposalRules gym = ProposalRules.of(TrainingProfile.builder().level(TrainingLevel.INTERMEDIATE).daysPerWeek(4)
                .minutesPerSession(60).location(TrainingLocation.GYM).build());
        assertThat(gym.equipment()).hasSize(ExerciseEquipment.values().length);
    }
}
