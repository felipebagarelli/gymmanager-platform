package com.felipebagarelli.gymmanager.invite.dto;

/** Link de convite do plano (F5). */
public final class InviteDtos {

    private InviteDtos() {
    }

    /** Para o personal compartilhar. */
    public record InviteLinkResponse(Long planId, String code, String url) {
    }

    /** O que quem recebe o link ve: so dados publicos do personal e do plano. */
    public record InvitePreview(String code, Long trainerId, String trainerName, String headline, String city, String state,
                                boolean online, boolean inPerson, String planName, String planDescription, int priceCents,
                                boolean available) {
    }
}
