package com.felipebagarelli.gymmanager.billing.service;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.SubscriptionResponse;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.entity.Plan;
import com.felipebagarelli.gymmanager.billing.entity.Subscription;
import com.felipebagarelli.gymmanager.billing.entity.SubscriptionStatus;
import com.felipebagarelli.gymmanager.billing.entity.TrainerPayoutAccount;
import com.felipebagarelli.gymmanager.billing.provider.CheckoutRequest;
import com.felipebagarelli.gymmanager.billing.provider.CheckoutSession;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.billing.repository.SubscriptionRepository;
import com.felipebagarelli.gymmanager.billing.repository.TrainerPayoutAccountRepository;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class SubscriptionService {

    private final PaymentProvider paymentProvider;
    private final SubscriptionRepository subscriptionRepository;
    private final PlanRepository planRepository;
    private final TrainerPayoutAccountRepository accountRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;
    private final BigDecimal platformFeePercent;
    private final String appUrl;

    public SubscriptionService(PaymentProvider paymentProvider,
                               SubscriptionRepository subscriptionRepository,
                               PlanRepository planRepository,
                               TrainerPayoutAccountRepository accountRepository,
                               StudentProfileRepository studentProfileRepository,
                               TrainerProfileRepository trainerProfileRepository,
                               TrainerStudentRepository trainerStudentRepository,
                               @Value("${app.billing.platform-fee-percent}") BigDecimal platformFeePercent,
                               @Value("${app.billing.app-url}") String appUrl) {
        this.paymentProvider = paymentProvider;
        this.subscriptionRepository = subscriptionRepository;
        this.planRepository = planRepository;
        this.accountRepository = accountRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
        this.platformFeePercent = platformFeePercent;
        this.appUrl = appUrl;
    }

    private SubscriptionResponse toResponse(Subscription s) {
        return new SubscriptionResponse(s.getId(), s.getStatus(), s.getPlan().getId(), s.getPlan().getName(),
                s.getPlan().getPriceCents(), s.getCurrentPeriodEnd(), s.getStudent().getId(), s.getStudent().getName());
    }

    private StudentProfile studentOf(String email) {
        return studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
    }

    private String base() {
        return appUrl.endsWith("/") ? appUrl.substring(0, appUrl.length() - 1) : appUrl;
    }

    /**
     * Cria a assinatura PENDING e devolve o link do checkout. So passa a valer (ACTIVE) quando o
     * webhook confirmar o pagamento: o retorno do navegador nunca e usado como prova.
     */
    @Transactional
    public UrlResponse subscribe(Long planId, String studentEmail) {
        StudentProfile student = studentOf(studentEmail);
        Plan plan = planRepository.findById(planId)
                .orElseThrow(() -> new ResourceNotFoundException("Plano não encontrado!"));

        TrainerStudent link = trainerStudentRepository.findByStudentId(student.getId())
                // ativo, ou contratacao pelo hub aguardando o pagamento
                .filter(l -> l.getStatus() == TrainerStudentStatus.ACTIVE || l.getStatus() == TrainerStudentStatus.INVITED)
                .orElseThrow(() -> new AccessDeniedException("Você não está vinculado a um personal ativo."));
        if (!plan.isActive() || !plan.getTrainer().getId().equals(link.getTrainer().getId())) {
            throw new AccessDeniedException("Este plano não está disponível para você.");
        }

        Optional<Subscription> latest = subscriptionRepository.findFirstByStudentIdOrderByIdDesc(student.getId());
        if (latest.isPresent() && (latest.get().getStatus() == SubscriptionStatus.ACTIVE
                || latest.get().getStatus() == SubscriptionStatus.PAST_DUE)) {
            throw new ConflictException("Você já possui uma assinatura em andamento.");
        }

        TrainerPayoutAccount account = accountRepository.findByTrainerId(plan.getTrainer().getId())
                .filter(TrainerPayoutAccount::isChargesEnabled)
                .orElseThrow(() -> new ConflictException("Seu personal ainda não habilitou o recebimento de pagamentos."));

        latest.filter(s -> s.getStatus() == SubscriptionStatus.PENDING).ifPresent(old -> {
            old.setStatus(SubscriptionStatus.CANCELED);
            old.setUpdatedAt(LocalDateTime.now());
            subscriptionRepository.save(old);
        });

        LocalDateTime now = LocalDateTime.now();
        Subscription subscription = subscriptionRepository.save(Subscription.builder()
                .student(student).trainer(plan.getTrainer()).plan(plan)
                .status(SubscriptionStatus.PENDING).createdAt(now).updatedAt(now).build());

        CheckoutSession session = paymentProvider.createCheckout(new CheckoutRequest(
                account.getStripeAccountId(), studentEmail, plan.getName(), plan.getPriceCents(),
                platformFeePercent, subscription.getId(),
                base() + "/assinatura?retorno=ok", base() + "/assinatura?retorno=cancelado"));
        return new UrlResponse(session.url());
    }

    /**
     * Link para o aluno em atraso quitar a cobranca em aberto. So vale para assinatura PAST_DUE; quem
     * confirma o pagamento e o webhook do provedor (o retorno do navegador nunca e usado como prova).
     */
    public UrlResponse regularize(String studentEmail) {
        Subscription subscription = subscriptionRepository
                .findFirstByStudentIdOrderByIdDesc(studentOf(studentEmail).getId())
                .filter(s -> s.getStatus() == SubscriptionStatus.PAST_DUE)
                .orElseThrow(() -> new ConflictException("Sua mensalidade não está em atraso."));
        if (subscription.getStripeSubscriptionId() == null) {
            throw new ConflictException("Não há cobrança em aberto para esta assinatura.");
        }
        String accountId = accountRepository.findByTrainerId(subscription.getTrainer().getId())
                .map(TrainerPayoutAccount::getStripeAccountId)
                .orElseThrow(() -> new ConflictException("Conta de recebimento do personal não encontrada."));
        String url = paymentProvider.createRegularizationLink(accountId, subscription.getStripeSubscriptionId())
                .orElseThrow(() -> new ConflictException(
                        "Ainda não há cobrança em aberto para pagar. Tente novamente em instantes."));
        return new UrlResponse(url);
    }

    public Optional<SubscriptionResponse> mine(String studentEmail) {
        return subscriptionRepository.findFirstByStudentIdOrderByIdDesc(studentOf(studentEmail).getId())
                .map(this::toResponse);
    }

    @Transactional
    public SubscriptionResponse cancel(String studentEmail) {
        Subscription subscription = subscriptionRepository
                .findFirstByStudentIdOrderByIdDesc(studentOf(studentEmail).getId())
                .filter(s -> s.getStatus() != SubscriptionStatus.CANCELED)
                .orElseThrow(() -> new ResourceNotFoundException("Você não possui assinatura para cancelar."));

        if (subscription.getStripeSubscriptionId() != null) {
            String accountId = accountRepository.findByTrainerId(subscription.getTrainer().getId())
                    .map(TrainerPayoutAccount::getStripeAccountId)
                    .orElseThrow(() -> new ConflictException("Conta de recebimento do personal não encontrada."));
            paymentProvider.cancelSubscription(accountId, subscription.getStripeSubscriptionId());
        }
        subscription.setStatus(SubscriptionStatus.CANCELED);
        subscription.setUpdatedAt(LocalDateTime.now());
        return toResponse(subscriptionRepository.save(subscription));
    }

    /** Assinaturas dos alunos do personal (pendentes nao aparecem: ainda nao viraram cobranca). */
    public List<SubscriptionResponse> forTrainer(String trainerEmail) {
        TrainerProfile trainer = trainerProfileRepository.findByUserEmail(trainerEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
        return subscriptionRepository.findByTrainerIdOrderByIdDesc(trainer.getId()).stream()
                .filter(s -> s.getStatus() != SubscriptionStatus.PENDING)
                .map(this::toResponse)
                .toList();
    }
}
