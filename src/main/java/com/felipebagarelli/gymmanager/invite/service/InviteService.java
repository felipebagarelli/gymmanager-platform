package com.felipebagarelli.gymmanager.invite.service;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.entity.Plan;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.hub.service.HubService;
import com.felipebagarelli.gymmanager.invite.dto.InviteDtos.InviteLinkResponse;
import com.felipebagarelli.gymmanager.invite.dto.InviteDtos.InvitePreview;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.util.Locale;

/**
 * Link de convite do plano (F5): o personal compartilha; quem recebe cria a propria conta e assina.
 * O vinculo nasce pendente e so fica ativo com o pagamento confirmado (mesmo fluxo do hub).
 */
@Service
public class InviteService {

    /** Sem letras e numeros que se confundem (0/o, 1/l/i). */
    private static final String ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789";
    private static final int CODE_LENGTH = 10;

    private final PlanRepository planRepository;
    private final HubService hubService;
    private final String publicUrl;
    private final SecureRandom random = new SecureRandom();

    public InviteService(PlanRepository planRepository, HubService hubService, @Value("${app.public-url}") String publicUrl) {
        this.planRepository = planRepository;
        this.hubService = hubService;
        this.publicUrl = publicUrl.endsWith("/") ? publicUrl.substring(0, publicUrl.length() - 1) : publicUrl;
    }

    /** O link do plano (gera o codigo na primeira vez). So o personal dono, com o plano ativo. */
    @Transactional
    public InviteLinkResponse link(Long planId, String email) {
        Plan plan = ownPlan(planId, email);
        if (plan.getInviteCode() == null) {
            plan.setInviteCode(newCode());
            planRepository.save(plan);
        }
        return toLink(plan);
    }

    /** Troca o codigo: o link antigo para de funcionar. */
    @Transactional
    public InviteLinkResponse reset(Long planId, String email) {
        Plan plan = ownPlan(planId, email);
        plan.setInviteCode(newCode());
        planRepository.save(plan);
        return toLink(plan);
    }

    public InvitePreview preview(String code) {
        Plan plan = byCode(code);
        TrainerProfile t = plan.getTrainer();
        return new InvitePreview(plan.getInviteCode(), t.getId(), t.getDisplayName(), t.getHeadline(), t.getCity(), t.getState(),
                t.isOnline(), t.isInPerson(), plan.getName(), plan.getDescription(), plan.getPriceCents(), hubService.canHire(t));
    }

    @Transactional
    public UrlResponse accept(String code, String email) {
        return hubService.hireByInvite(byCode(code), email);
    }

    // ----------------------------------------------------------------

    private Plan ownPlan(Long planId, String email) {
        Plan plan = planRepository.findById(planId).orElseThrow(() -> new ResourceNotFoundException("Plano não encontrado!"));
        if (!plan.getTrainer().getUser().getEmail().equalsIgnoreCase(email)) {
            throw new AccessDeniedException("Este plano não é seu.");
        }
        if (!plan.isActive()) {
            throw new ConflictException("Este plano está desativado. Ative-o para compartilhar.");
        }
        return plan;
    }

    /** Codigo desconhecido, plano desativado ou personal inativo: "convite nao encontrado" (sem dizer qual). */
    private Plan byCode(String code) {
        String normalized = code == null ? "" : code.trim().toLowerCase(Locale.ROOT);
        return planRepository.findByInviteCode(normalized)
                .filter(Plan::isActive)
                .filter(p -> p.getTrainer().getUser().isActive())
                .orElseThrow(() -> new ResourceNotFoundException("Convite não encontrado. Peça um link novo ao seu personal."));
    }

    private String newCode() {
        for (int attempt = 0; attempt < 5; attempt++) {
            StringBuilder sb = new StringBuilder(CODE_LENGTH);
            for (int i = 0; i < CODE_LENGTH; i++) {
                sb.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
            }
            String code = sb.toString();
            if (planRepository.findByInviteCode(code).isEmpty()) return code;
        }
        throw new IllegalStateException("Não foi possível gerar o código do convite.");
    }

    private InviteLinkResponse toLink(Plan plan) {
        return new InviteLinkResponse(plan.getId(), plan.getInviteCode(), publicUrl + "/convite/" + plan.getInviteCode());
    }
}
