package com.felipebagarelli.gymmanager.billing.service;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.PlanRequest;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.PlanResponse;
import com.felipebagarelli.gymmanager.billing.entity.Plan;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class PlanService {

    private final PlanRepository planRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;

    public PlanService(PlanRepository planRepository,
                       TrainerProfileRepository trainerProfileRepository,
                       TrainerStudentRepository trainerStudentRepository) {
        this.planRepository = planRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
    }

    private PlanResponse toResponse(Plan plan) {
        return new PlanResponse(plan.getId(), plan.getName(), plan.getDescription(), plan.getPriceCents(), plan.isActive());
    }

    private TrainerProfile trainerOf(String email) {
        return trainerProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
    }

    private Plan ownedPlan(Long id, String email) {
        Plan plan = planRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Plano não encontrado!"));
        if (!plan.getTrainer().getUser().getEmail().equalsIgnoreCase(email)) {
            throw new AccessDeniedException("Você não tem permissão para alterar este plano.");
        }
        return plan;
    }

    public List<PlanResponse> mine(String trainerEmail) {
        return planRepository.findByTrainerIdOrderByPriceCentsAsc(trainerOf(trainerEmail).getId())
                .stream().map(this::toResponse).toList();
    }

    @Transactional
    public PlanResponse create(PlanRequest request, String trainerEmail) {
        Plan plan = planRepository.save(Plan.builder()
                .trainer(trainerOf(trainerEmail))
                .name(request.name().trim())
                .description(request.description())
                .priceCents(request.priceCents())
                .active(request.active() == null || request.active())
                .createdAt(LocalDateTime.now())
                .build());
        return toResponse(plan);
    }

    /** O preco muda so para novas assinaturas: as ja criadas seguem com o valor contratado na Stripe. */
    @Transactional
    public PlanResponse update(Long id, PlanRequest request, String trainerEmail) {
        Plan plan = ownedPlan(id, trainerEmail);
        plan.setName(request.name().trim());
        plan.setDescription(request.description());
        plan.setPriceCents(request.priceCents());
        if (request.active() != null) {
            plan.setActive(request.active());
        }
        return toResponse(planRepository.save(plan));
    }

    /** Planos nunca sao apagados (ha assinaturas historicas): apenas desativados. */
    @Transactional
    public void deactivate(Long id, String trainerEmail) {
        Plan plan = ownedPlan(id, trainerEmail);
        plan.setActive(false);
        planRepository.save(plan);
    }

    /** Planos ativos do personal ao qual o aluno esta vinculado. */
    public List<PlanResponse> availableForStudent(String studentEmail) {
        return trainerStudentRepository.findByStudentUserEmail(studentEmail).stream()
                .filter(link -> link.getStatus() == TrainerStudentStatus.ACTIVE)
                .map(TrainerStudent::getTrainer)
                .flatMap(trainer -> planRepository.findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(trainer.getId()).stream())
                .map(this::toResponse)
                .toList();
    }
}
