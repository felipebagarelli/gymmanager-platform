package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.session.entity.Effort;

/**
 * Resumo do que o aluno fez num exercicio do plano nas ultimas sessoes: base para a IA sugerir
 * progressao, e para o servidor limitar o quanto ela pode subir.
 */
public record ExerciseHistory(Long workoutExerciseId, int sessionsDone, Double lastMaxLoad, int lastBestReps,
                              Effort lastEffort) {

    /** Pode subir carga: ja fez pelo menos 2 vezes e a ultima nao foi "dificil". */
    public boolean canIncreaseLoad() {
        return sessionsDone >= 2 && lastEffort != Effort.HARD && lastMaxLoad != null;
    }
}
