package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.AdjustmentChange;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.AdjustmentContent;
import com.felipebagarelli.gymmanager.entity.ExerciseEquipment;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLevel;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLocation;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.session.entity.Effort;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** D4: ajustes da IA limitados pelo servidor e aplicados so com o plano intacto. */
class AdjustmentTest {

    private final Workout workout = Workout.builder().id(10L).name("Treino A").build();
    private final Exercises goblet = Exercises.builder().id(1L).catalogCode("agachamento_goblet").name("Agachamento goblet")
            .muscleGroup("Pernas").equipment(ExerciseEquipment.DUMBBELL).build();
    private final Exercises flexao = Exercises.builder().id(2L).catalogCode("flexao_de_braco").name("Flexão de braço")
            .muscleGroup("Peito").equipment(ExerciseEquipment.BODYWEIGHT).build();
    private final Exercises afundo = Exercises.builder().id(3L).catalogCode("afundo_com_halteres").name("Afundo com halteres")
            .muscleGroup("Pernas").equipment(ExerciseEquipment.DUMBBELL).build();
    private final Exercises supinoHalter = Exercises.builder().id(4L).catalogCode("supino_reto_com_halteres").name("Supino reto com halteres")
            .muscleGroup("Peito").equipment(ExerciseEquipment.DUMBBELL).build();

    private WorkoutExercises gobletItem;
    private WorkoutExercises flexaoItem;
    private List<WorkoutExercises> plan;
    private final Map<String, Exercises> catalog = new LinkedHashMap<>();
    private final Map<Long, ExerciseHistory> history = new HashMap<>();
    private ProposalRules rules;

    @BeforeEach
    void setUp() {
        gobletItem = WorkoutExercises.builder().id(100L).workout(workout).exercise(goblet).sets(3).reps(12)
                .restSeconds(60).targetLoad(20.0).position(1).build();
        flexaoItem = WorkoutExercises.builder().id(101L).workout(workout).exercise(flexao).sets(3).reps(10)
                .restSeconds(60).position(2).build();
        plan = new ArrayList<>(List.of(gobletItem, flexaoItem));
        for (Exercises e : List.of(goblet, flexao, afundo, supinoHalter)) catalog.put(e.getCatalogCode(), e);
        rules = ProposalRules.of(TrainingProfile.builder().level(TrainingLevel.INTERMEDIATE).daysPerWeek(3)
                .minutesPerSession(60).location(TrainingLocation.HOME).equipment("DUMBBELLS").build());
        history.put(100L, new ExerciseHistory(100L, 3, 20.0, 12, Effort.EASY));
        history.put(101L, new ExerciseHistory(101L, 3, null, 10, Effort.IDEAL));
    }

    private AdjustmentContent parse(String json) {
        return AdjustmentParser.parse(json, workout, plan, history, catalog, rules);
    }

    @Test
    void progress_loadUpToTenPercent_setsChangeByOne_noInventedLoad() {
        AdjustmentContent content = parse("""
                {"summary": "Hora de progredir.", "changes": [
                  {"workoutExerciseId": 100, "action": "PROGRESS", "sets": 6, "reps": 12, "restSeconds": 60, "targetLoad": 40, "note": "Suba a carga"},
                  {"workoutExerciseId": 101, "action": "PROGRESS", "sets": 3, "reps": 14, "restSeconds": 60, "targetLoad": 15}
                ]}
                """);
        AdjustmentChange goblet = content.changes().get(0);
        assertThat(goblet.setsAfter()).isEqualTo(4);        // no maximo +1 serie
        assertThat(goblet.loadAfter()).isEqualTo(22.0);     // 20 kg + 10% = 22 (nunca 40)
        assertThat(goblet.loadBefore()).isEqualTo(20.0);
        AdjustmentChange flexao = content.changes().get(1);
        assertThat(flexao.repsAfter()).isEqualTo(14);
        assertThat(flexao.loadAfter()).isNull();            // sem historico de carga: nao inventa numero
        assertThat(content.workoutName()).isEqualTo("Treino A");
    }

    @Test
    void hardLastSession_orTooFewSessions_blocksLoadIncrease() {
        history.put(100L, new ExerciseHistory(100L, 3, 20.0, 8, Effort.HARD));
        assertThat(parse("""
                {"changes": [{"workoutExerciseId": 100, "action": "PROGRESS", "sets": 3, "reps": 10, "targetLoad": 25}]}
                """).changes().getFirst().loadAfter()).isEqualTo(20.0);

        history.put(100L, new ExerciseHistory(100L, 1, 20.0, 12, Effort.EASY));
        assertThat(parse("""
                {"changes": [{"workoutExerciseId": 100, "action": "PROGRESS", "sets": 3, "reps": 13, "targetLoad": 21}]}
                """).changes().getFirst().loadAfter()).isEqualTo(20.0);

        // reduzir e permitido (ate 30%)
        assertThat(parse("""
                {"changes": [{"workoutExerciseId": 100, "action": "PROGRESS", "sets": 3, "reps": 12, "targetLoad": 2}]}
                """).changes().getFirst().loadAfter()).isEqualTo(14.0);
    }

    @Test
    void swap_onlySameGroup_inCatalog_notAlreadyInPlan() {
        AdjustmentContent content = parse("""
                {"changes": [
                  {"workoutExerciseId": 100, "action": "SWAP", "newCode": "supino_reto_com_halteres", "sets": 3, "reps": 10},
                  {"workoutExerciseId": 101, "action": "SWAP", "newCode": "supino_reto_com_halteres", "sets": 3, "reps": 10}
                ]}
                """);
        // goblet (Pernas) -> supino (Peito): recusado; flexao (Peito) -> supino com halteres: aceito
        assertThat(content.changes()).singleElement().satisfies(c -> {
            assertThat(c.action()).isEqualTo("SWAP");
            assertThat(c.workoutExerciseId()).isEqualTo(101L);
            assertThat(c.newExerciseName()).isEqualTo("Supino reto com halteres");
            assertThat(c.loadAfter()).isNull();
        });

        assertThatThrownBy(() -> parse("""
                {"changes": [{"workoutExerciseId": 100, "action": "SWAP", "newCode": "flexao_de_braco"},
                             {"workoutExerciseId": 101, "action": "SWAP", "newCode": "inventado"}]}
                """)).isInstanceOf(BadRequestException.class);
    }

    @Test
    void unknownItems_duplicates_noChanges_andRefusal() {
        assertThatThrownBy(() -> parse("""
                {"changes": [{"workoutExerciseId": 999, "action": "PROGRESS", "reps": 12},
                             {"workoutExerciseId": 101, "action": "PROGRESS", "sets": 3, "reps": 10, "restSeconds": 60}]}
                """)).isInstanceOf(BadRequestException.class).hasMessageContaining("Continue assim");
        assertThatThrownBy(() -> parse("{\"refused\": true, \"reason\": \"Procure um fisioterapeuta.\"}"))
                .isInstanceOf(BadRequestException.class).hasMessageContaining("fisioterapeuta");
        assertThatThrownBy(() -> parse("nada")).isInstanceOf(AiProviderException.class);
    }

    // ---------------------------------------------------------------- aplicar

    private AdjustmentApplier applier(WorkoutExercisesRepository planRepo, ExercisePerformanceRepository perf) {
        ExerciseRepository exercises = mock(ExerciseRepository.class);
        when(exercises.findById(4L)).thenReturn(Optional.of(supinoHalter));
        return new AdjustmentApplier(planRepo, exercises, perf);
    }

    @Test
    void apply_progressAndSwap_keepingHistory() {
        WorkoutExercisesRepository planRepo = mock(WorkoutExercisesRepository.class);
        when(planRepo.findById(100L)).thenReturn(Optional.of(gobletItem));
        when(planRepo.findById(101L)).thenReturn(Optional.of(flexaoItem));
        List<WorkoutExercises> saved = new ArrayList<>();
        when(planRepo.save(any(WorkoutExercises.class))).thenAnswer(i -> {
            saved.add(i.getArgument(0));
            return i.getArgument(0);
        });
        ExercisePerformanceRepository perf = mock(ExercisePerformanceRepository.class);
        when(perf.existsByWorkoutExerciseId(101L)).thenReturn(true);

        AdjustmentContent content = parse("""
                {"changes": [
                  {"workoutExerciseId": 100, "action": "PROGRESS", "sets": 4, "reps": 12, "restSeconds": 75, "targetLoad": 22},
                  {"workoutExerciseId": 101, "action": "SWAP", "newCode": "supino_reto_com_halteres", "sets": 3, "reps": 10, "note": "Banco plano"}
                ]}
                """);
        applier(planRepo, perf).apply(content);

        assertThat(gobletItem.getSets()).isEqualTo(4);
        assertThat(gobletItem.getRestSeconds()).isEqualTo(75);
        assertThat(gobletItem.getTargetLoad()).isEqualTo(22.0);
        // a flexao ja tinha series: sai do plano, mas nao e apagada
        assertThat(flexaoItem.getRemovedAt()).isNotNull();
        verify(planRepo, never()).delete(flexaoItem);
        assertThat(saved).anySatisfy(item -> {
            assertThat(item.getExercise()).isSameAs(supinoHalter);
            assertThat(item.getPosition()).isEqualTo(2);
            assertThat(item.getNotes()).isEqualTo("Banco plano");
        });
    }

    @Test
    void apply_refusesWhenThePlanChanged() {
        AdjustmentContent content = parse("""
                {"changes": [{"workoutExerciseId": 100, "action": "PROGRESS", "sets": 4, "reps": 12}]}
                """);
        WorkoutExercisesRepository planRepo = mock(WorkoutExercisesRepository.class);
        gobletItem.setSets(5); // o aluno mudou o treino depois da proposta
        when(planRepo.findById(anyLong())).thenReturn(Optional.of(gobletItem));

        assertThatThrownBy(() -> applier(planRepo, mock(ExercisePerformanceRepository.class)).apply(content))
                .isInstanceOf(ConflictException.class);
        verify(planRepo, never()).save(any());
    }
}
