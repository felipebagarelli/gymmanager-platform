package com.felipebagarelli.gymmanager.dto.response;

public record WorkoutResponse(
        Long id,
        String name,
        Long trainerId,
        /* exercicios no plano atual */
        Integer exerciseCount,
        /* alunos com o treino ativo (so para o personal dono; null para os demais) */
        Integer studentCount
) {
}
