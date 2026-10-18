package com.felipebagarelli.gymmanager.hub.dto;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.PlanResponse;
import com.felipebagarelli.gymmanager.hub.entity.TrainerSpecialty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.Set;

public final class HubDtos {

    private HubDtos() {
    }

    /** O que o personal edita. */
    public record PublicProfileRequest(
            boolean listed,
            @Size(max = 120) String headline,
            @Size(max = 1000) String bio,
            @Size(max = 80) String city,
            @Pattern(regexp = "^$|^[A-Za-z]{2}$", message = "UF com 2 letras") String state,
            boolean online,
            boolean inPerson,
            Set<TrainerSpecialty> specialties
    ) {
    }

    /** O que o personal ve: o perfil e por que (ainda) nao aparece no hub. */
    public record PublicProfileResponse(boolean listed, String headline, String bio, String city, String state,
                                        boolean online, boolean inPerson, List<TrainerSpecialty> specialties,
                                        boolean visible, List<String> missing) {
    }

    /** Cartao da busca (nunca traz e-mail ou telefone). */
    public record TrainerCard(Long id, String displayName, String headline, String city, String state,
                              boolean online, boolean inPerson, List<TrainerSpecialty> specialties,
                              int fromPriceCents) {
    }

    public record TrainerDetail(Long id, String displayName, String headline, String bio, String city, String state,
                                boolean online, boolean inPerson, List<TrainerSpecialty> specialties,
                                List<PlanResponse> plans) {
    }

    public record HireRequest(@NotNull Long planId) {
    }
}
