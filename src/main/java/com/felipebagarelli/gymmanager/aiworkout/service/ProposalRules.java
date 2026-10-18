package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.entity.ExerciseEquipment;
import com.felipebagarelli.gymmanager.onboarding.entity.Equipment;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLevel;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLocation;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;

import java.util.EnumSet;
import java.util.Set;

/**
 * Limites de seguranca da proposta, aplicados pelo servidor (a IA nunca e a ultima palavra):
 * quantos treinos, quantos exercicios, series, repeticoes e descanso, por nivel e tempo disponivel.
 * Nao ha carga sugerida: o aluno comeca leve e ajusta.
 */
public record ProposalRules(int maxWorkouts, int minExercises, int maxExercises, int minSets, int maxSets,
                            int minReps, int maxReps, Set<ExerciseEquipment> equipment) {

    public static final int MIN_REST = 30;
    public static final int MAX_REST = 180;
    /** Exercicio por tempo ("(segundos)"): o numero de repeticoes vale como segundos. */
    public static final int MIN_SECONDS = 15;
    public static final int MAX_SECONDS = 60;
    /** Exercicio por tempo ("(minutos)"). */
    public static final int MIN_MINUTES = 5;
    public static final int MAX_MINUTES = 30;

    public static ProposalRules of(TrainingProfile profile) {
        int maxByLevel;
        int minSets;
        int maxSets;
        int minReps;
        int maxReps;
        switch (profile.getLevel()) {
            case BEGINNER -> { maxByLevel = 6; minSets = 2; maxSets = 3; minReps = 8; maxReps = 15; }
            case INTERMEDIATE -> { maxByLevel = 7; minSets = 3; maxSets = 4; minReps = 6; maxReps = 15; }
            default -> { maxByLevel = 8; minSets = 3; maxSets = 5; minReps = 5; maxReps = 15; }
        }
        // cerca de 9 minutos por exercicio (series + descanso + troca de aparelho)
        int byTime = Math.max(3, profile.getMinutesPerSession() / 9);
        int maxExercises = Math.max(3, Math.min(maxByLevel, byTime));
        int minExercises = Math.min(profile.getLevel() == TrainingLevel.BEGINNER ? 3 : 4, maxExercises);
        int maxWorkouts = Math.max(1, Math.min(profile.getDaysPerWeek(), 5));
        return new ProposalRules(maxWorkouts, minExercises, maxExercises, minSets, maxSets, minReps, maxReps,
                allowedEquipment(profile));
    }

    /** Equipamento que o aluno tem: academia = tudo; casa = o que marcou + peso do corpo. */
    static Set<ExerciseEquipment> allowedEquipment(TrainingProfile profile) {
        if (profile.getLocation() == TrainingLocation.GYM) {
            return EnumSet.allOf(ExerciseEquipment.class);
        }
        Set<ExerciseEquipment> allowed = EnumSet.of(ExerciseEquipment.BODYWEIGHT);
        if (profile.getLocation() == TrainingLocation.HOME && profile.getEquipment() != null) {
            for (String raw : profile.getEquipment().split(",")) {
                if (raw.isBlank()) continue;
                switch (Equipment.valueOf(raw.trim())) {
                    case DUMBBELLS -> allowed.add(ExerciseEquipment.DUMBBELL);
                    case BARBELL -> allowed.add(ExerciseEquipment.BARBELL);
                    case KETTLEBELL -> allowed.add(ExerciseEquipment.KETTLEBELL);
                    case BANDS -> allowed.add(ExerciseEquipment.BAND);
                    case PULL_UP_BAR -> allowed.add(ExerciseEquipment.PULL_UP_BAR);
                    case MACHINES -> allowed.add(ExerciseEquipment.MACHINE);
                    case BENCH -> {
                        // banco ajuda nos exercicios com halteres/barra, mas nao libera nenhum sozinho
                    }
                }
            }
        }
        return allowed;
    }
}
