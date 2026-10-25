package com.felipebagarelli.gymmanager.dto;

import com.felipebagarelli.gymmanager.entity.RoutineMode;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Esquema de treino do aluno (F3). */
public final class RoutineDtos {

    private RoutineDtos() {
    }

    public record RoutineItem(Long workoutId, String workoutName, int order) {
    }

    /** O esquema e o proximo treino da sequencia (null fora do modo sequencia). */
    public record RoutineResponse(Long studentId, RoutineMode mode, List<RoutineItem> sequence, Long nextWorkoutId) {
    }

    /** Modo e, na sequencia, a ordem dos treinos (os treinos precisam estar ativos para o aluno). */
    public record SetRoutineRequest(@NotNull RoutineMode mode, @Size(max = 14) List<@NotNull Long> workoutIds) {
    }

    public record SkipRequest(@NotNull Long workoutId) {
    }

    /** Aplica a mesma sequencia a varios alunos do personal (atribui o que faltar). */
    public record BatchRoutineRequest(@NotEmpty @Size(max = 200) List<@NotNull Long> studentIds,
                                      @NotEmpty @Size(max = 14) List<@NotNull Long> workoutIds) {
    }
}
