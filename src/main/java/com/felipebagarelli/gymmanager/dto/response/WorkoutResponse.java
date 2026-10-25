package com.felipebagarelli.gymmanager.dto.response;

public record WorkoutResponse(
        Long id,
        String name,
        Long trainerId,
        /* exercicios no plano atual */
        Integer exerciseCount,
        /* alunos com o treino ativo (so para o personal dono; null para os demais) */
        Integer studentCount,
        /* dias da semana deste treino para o aluno (so na lista de treinos de um aluno; null nas demais) */
        java.util.List<Integer> weekdays
) {
}
