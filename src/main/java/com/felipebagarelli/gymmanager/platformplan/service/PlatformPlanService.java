package com.felipebagarelli.gymmanager.platformplan.service;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.provider.CheckoutSession;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.provider.PlatformCheckoutRequest;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.Offer;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.PlatformPlanResponse;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.SubscriptionInfo;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.Tier;
import com.felipebagarelli.gymmanager.platformplan.entity.BillingInterval;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscription;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscriptionStatus;
import com.felipebagarelli.gymmanager.platformplan.repository.PlatformSubscriptionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Period;
import java.util.Optional;

/**
 * Plano da plataforma (GymManager Pro) do aluno sem personal: gratis (registrar treinos + 1 treino
 * gerado por mes) ou Pro (sem limite). Quem confirma o pagamento e o webhook.
 */
@Service
public class PlatformPlanService {

    public static final String PRODUCT_NAME = "GymManager Pro";
    public static final int FREE_AI_WORKOUTS_PER_MONTH = 1;
    private static final int ADULT_AGE = 18;

    private final PlatformSubscriptionRepository repository;
    private final StudentProfileRepository studentProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;
    private final PaymentProvider paymentProvider;
    private final int monthlyCents;
    private final int yearlyCents;
    private final int trialDays;
    private final boolean enabled;
    private final String publicUrl;
    private final Clock clock;

    @Autowired
    public PlatformPlanService(PlatformSubscriptionRepository repository,
                               StudentProfileRepository studentProfileRepository,
                               TrainerStudentRepository trainerStudentRepository,
                               PaymentProvider paymentProvider,
                               @Value("${app.platform-plan.monthly-cents:1990}") int monthlyCents,
                               @Value("${app.platform-plan.yearly-cents:14990}") int yearlyCents,
                               @Value("${app.platform-plan.trial-days:7}") int trialDays,
                               @Value("${app.platform-plan.enabled:false}") boolean enabled,
                               @Value("${app.public-url}") String publicUrl) {
        this(repository, studentProfileRepository, trainerStudentRepository, paymentProvider,
                monthlyCents, yearlyCents, trialDays, enabled, publicUrl, Clock.systemDefaultZone());
    }

    PlatformPlanService(PlatformSubscriptionRepository repository,
                        StudentProfileRepository studentProfileRepository,
                        TrainerStudentRepository trainerStudentRepository,
                        PaymentProvider paymentProvider,
                        int monthlyCents, int yearlyCents, int trialDays, boolean enabled, String publicUrl, Clock clock) {
        this.repository = repository;
        this.studentProfileRepository = studentProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
        this.paymentProvider = paymentProvider;
        this.monthlyCents = monthlyCents;
        this.yearlyCents = yearlyCents;
        this.trialDays = trialDays;
        this.enabled = enabled;
        this.publicUrl = publicUrl.endsWith("/") ? publicUrl.substring(0, publicUrl.length() - 1) : publicUrl;
        this.clock = clock;
    }

    private StudentProfile studentOf(String email) {
        return studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }

    /** Em teste ou ativa: Pro. Cancelada no fim do periodo continua Pro ate o webhook encerrar. */
    public static boolean grantsPro(PlatformSubscription s) {
        return s.getStatus() == PlatformSubscriptionStatus.TRIALING || s.getStatus() == PlatformSubscriptionStatus.ACTIVE;
    }

    public boolean isPro(StudentProfile student) {
        return repository.findFirstByStudentIdOrderByIdDesc(student.getId()).map(PlatformPlanService::grantsPro).orElse(false);
    }

    /** Motivo para nao poder assinar (null = pode). */
    private String unavailableReason(StudentProfile student, Optional<PlatformSubscription> latest) {
        // so abre as vendas quando o Pro entregar algo a mais (treinos pela IA, Fase D)
        if (!enabled) {
            return "A assinatura Pro abre em breve.";
        }
        boolean withTrainer = trainerStudentRepository.findByStudentId(student.getId())
                .map(l -> l.getStatus() == TrainerStudentStatus.ACTIVE || l.getStatus() == TrainerStudentStatus.PAUSED)
                .orElse(false);
        if (withTrainer) {
            return "Você treina com um personal: os treinos e a mensalidade são com ele.";
        }
        if (student.getBirthDate() == null || Period.between(student.getBirthDate(), LocalDate.now(clock)).getYears() < ADULT_AGE) {
            return "Para menores de 18 anos, a assinatura depende da aprovação do responsável (em breve).";
        }
        if (latest.isPresent() && latest.get().getStatus() != PlatformSubscriptionStatus.CANCELED
                && latest.get().getStatus() != PlatformSubscriptionStatus.PENDING) {
            return "Você já tem uma assinatura.";
        }
        return null;
    }

    public PlatformPlanResponse status(String email) {
        StudentProfile student = studentOf(email);
        Optional<PlatformSubscription> latest = repository.findFirstByStudentIdOrderByIdDesc(student.getId());
        boolean pro = latest.map(PlatformPlanService::grantsPro).orElse(false);
        SubscriptionInfo info = latest
                .filter(s -> s.getStatus() != PlatformSubscriptionStatus.PENDING)
                .map(s -> new SubscriptionInfo(s.getStatus(), s.getBillingInterval(), s.getPriceCents(),
                        s.getCurrentPeriodEnd(), s.getTrialEnd(), s.isCancelAtPeriodEnd()))
                .orElse(null);
        String reason = unavailableReason(student, latest);
        boolean trialAvailable = trialDays > 0 && !repository.existsByStudentIdAndTrialEndIsNotNull(student.getId());
        return new PlatformPlanResponse(pro ? Tier.PRO : Tier.FREE, info,
                new Offer(monthlyCents, yearlyCents, trialDays, trialAvailable),
                pro ? null : FREE_AI_WORKOUTS_PER_MONTH, reason == null, reason);
    }

    /** Cria a assinatura PENDING e devolve o checkout. So vale quando o webhook confirmar. */
    @Transactional
    public UrlResponse subscribe(BillingInterval interval, String email) {
        StudentProfile student = studentOf(email);
        Optional<PlatformSubscription> latest = repository.findFirstByStudentIdOrderByIdDesc(student.getId());
        String reason = unavailableReason(student, latest);
        if (reason != null) {
            throw new ConflictException(reason);
        }
        // checkout antigo que nao foi concluido nao vale mais
        latest.filter(s -> s.getStatus() == PlatformSubscriptionStatus.PENDING).ifPresent(old -> {
            old.setStatus(PlatformSubscriptionStatus.CANCELED);
            old.setUpdatedAt(now());
            repository.save(old);
        });
        boolean yearly = interval == BillingInterval.YEARLY;
        int price = yearly ? yearlyCents : monthlyCents;
        int trial = trialDays > 0 && !repository.existsByStudentIdAndTrialEndIsNotNull(student.getId()) ? trialDays : 0;

        PlatformSubscription subscription = repository.save(PlatformSubscription.builder()
                .student(student)
                .status(PlatformSubscriptionStatus.PENDING)
                .billingInterval(interval)
                .priceCents(price)
                .createdAt(now())
                .updatedAt(now())
                .build());

        CheckoutSession session = paymentProvider.createPlatformCheckout(new PlatformCheckoutRequest(
                student.getUser().getEmail(), PRODUCT_NAME, price, yearly, trial, subscription.getId(),
                publicUrl + "/checkout/retorno?status=ok", publicUrl + "/checkout/retorno?status=cancelado"));
        return new UrlResponse(session.url());
    }

    private PlatformSubscription current(String email) {
        return repository.findFirstByStudentIdOrderByIdDesc(studentOf(email).getId())
                .filter(s -> s.getStripeSubscriptionId() != null && s.getStatus() != PlatformSubscriptionStatus.CANCELED)
                .orElseThrow(() -> new ConflictException("Você não tem uma assinatura ativa."));
    }

    /** Cancela no fim do periodo: continua Pro ate la. */
    @Transactional
    public PlatformPlanResponse cancel(String email) {
        PlatformSubscription s = current(email);
        paymentProvider.setPlatformCancelAtPeriodEnd(s.getStripeSubscriptionId(), true);
        s.setCancelAtPeriodEnd(true);
        s.setUpdatedAt(now());
        repository.save(s);
        return status(email);
    }

    /** Desfaz o cancelamento antes do fim do periodo. */
    @Transactional
    public PlatformPlanResponse resume(String email) {
        PlatformSubscription s = current(email);
        if (!s.isCancelAtPeriodEnd()) {
            throw new ConflictException("Sua assinatura não está cancelada.");
        }
        paymentProvider.setPlatformCancelAtPeriodEnd(s.getStripeSubscriptionId(), false);
        s.setCancelAtPeriodEnd(false);
        s.setUpdatedAt(now());
        repository.save(s);
        return status(email);
    }

    public UrlResponse regularize(String email) {
        PlatformSubscription s = current(email);
        if (s.getStatus() != PlatformSubscriptionStatus.PAST_DUE) {
            throw new ConflictException("Sua assinatura não está em atraso.");
        }
        return new UrlResponse(paymentProvider.createPlatformRegularizationLink(s.getStripeSubscriptionId())
                .orElseThrow(() -> new ConflictException("Ainda não há cobrança em aberto para pagar. Tente novamente em instantes.")));
    }
}
