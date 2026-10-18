package com.felipebagarelli.gymmanager.aiworkout.dto;

import com.felipebagarelli.gymmanager.aiworkout.entity.ProposalStatus;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;
import java.util.List;

public final class ProposalDtos {

    private ProposalDtos() {
    }

    public record ProposedExercise(Long exerciseId, String code, String name, String muscleGroup, String equipment,
                                   int sets, int reps, int restSeconds, String note) {
    }

    public record ProposedWorkout(String name, String focus, List<ProposedExercise> exercises) {
    }

    /** Proposta validada: e o que fica guardado e o que o app mostra na previa. */
    public record ProposalContent(String summary, List<ProposedWorkout> workouts) {
    }

    /** Uma mudanca proposta: PROGRESS (series/repeticoes/descanso/carga) ou SWAP (troca de exercicio). */
    public record AdjustmentChange(String action, Long workoutExerciseId, String exerciseName,
                                   Long newExerciseId, String newExerciseName,
                                   int setsBefore, int repsBefore, Integer restBefore, Double loadBefore,
                                   int setsAfter, int repsAfter, int restAfter, Double loadAfter, String note) {
    }

    public record AdjustmentContent(String summary, Long workoutId, String workoutName, List<AdjustmentChange> changes) {
    }

    /** {@code content} nas propostas de treino novo; {@code adjustment} nas de ajuste. */
    public record ProposalResponse(Long id, ProposalStatus status, ProposalContent content,
                                   LocalDateTime createdAt, List<Long> workoutIds,
                                   String kind, AdjustmentContent adjustment) {
    }

    /** Pode pedir uma proposta agora? Se nao, o motivo; e quantas ja usou no mes. */
    public record EligibilityResponse(boolean allowed, String reason, String reasonCode,
                                      long usedThisMonth, Integer monthlyLimit, boolean pro) {
    }

    public record CreateProposalRequest(@Size(max = 300) String note) {
    }
}
