package com.felipebagarelli.gymmanager.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Pedidos da agenda de treinos (dias da semana). */
public final class WorkoutScheduleRequests {

    private WorkoutScheduleRequests() {
    }

    /** Dias de uma atribuicao. */
    public record WeekdaysRequest(List<Integer> weekdays) {
    }

    /** Atribuir um treino a varios alunos de uma vez, nos mesmos dias. */
    public record BatchAssignRequest(@NotEmpty @Size(max = 200) List<@NotNull Long> studentIds, List<Integer> weekdays) {
    }

    /** A semana de um aluno: os dias de cada treino ativo dele. */
    public record StudentScheduleRequest(@NotNull @Size(max = 100) List<@Valid Item> items) {
        public record Item(@NotNull Long workoutId, List<Integer> weekdays) {
        }
    }
}
