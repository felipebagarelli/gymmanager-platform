package com.felipebagarelli.gymmanager.onboarding.dto;

import com.felipebagarelli.gymmanager.onboarding.entity.Equipment;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingGoal;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLevel;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLocation;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

public final class OnboardingDtos {

    private OnboardingDtos() {
    }

    public record TrainingProfileRequest(
            @NotNull TrainingGoal goal,
            @NotNull TrainingLevel level,
            @Min(1) @Max(7) int daysPerWeek,
            @Min(15) @Max(180) int minutesPerSession,
            @NotNull TrainingLocation location,
            Set<Equipment> equipment,
            /* opcionais: atualizam o cadastro do aluno */
            @DecimalMin("0.9") @DecimalMax("2.5") Double height,
            @DecimalMin("25") @DecimalMax("350") Double weight
    ) {
    }

    public record TrainingProfileResponse(
            TrainingGoal goal,
            TrainingLevel level,
            int daysPerWeek,
            int minutesPerSession,
            TrainingLocation location,
            List<Equipment> equipment,
            Double height,
            Double weight,
            LocalDateTime updatedAt
    ) {
    }

    /** Respostas na ordem das perguntas da versao vigente (true = sim). */
    public record HealthScreeningRequest(@NotNull @Size(min = 1, max = 20) List<Boolean> answers) {
    }

    public record HealthScreeningResponse(String version, boolean risk, LocalDateTime answeredAt) {
    }

    /** Situacao do onboarding: o app pede o que falta. */
    public record OnboardingResponse(
            TrainingProfileResponse trainingProfile,
            HealthScreeningResponse healthScreening,
            boolean completed,
            /* treino gerado por IA liberado (triagem respondida ha menos de 12 meses e sem risco) */
            boolean aiWorkoutsAllowed,
            /* triagem com mais de 12 meses: pedir para responder de novo */
            boolean screeningExpired,
            /* o aluno autorizou o personal a ver estas respostas */
            boolean shareWithTrainer
    ) {
    }

    public record ShareRequest(boolean share) {
    }

    /** Visao do personal: so com a autorizacao do aluno. */
    public record TrainerHealthView(boolean shared, TrainingProfileResponse trainingProfile, String screeningVersion,
                                    Boolean risk, LocalDateTime answeredAt, List<Boolean> answers) {
    }
}
