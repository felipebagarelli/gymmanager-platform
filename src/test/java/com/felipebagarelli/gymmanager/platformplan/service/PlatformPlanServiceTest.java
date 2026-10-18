package com.felipebagarelli.gymmanager.platformplan.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.billing.entity.BillingEvent;
import com.felipebagarelli.gymmanager.billing.provider.CheckoutSession;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.provider.PlatformBillingNotification;
import com.felipebagarelli.gymmanager.billing.provider.PlatformBillingNotification.Type;
import com.felipebagarelli.gymmanager.billing.provider.PlatformCheckoutRequest;
import com.felipebagarelli.gymmanager.billing.repository.BillingEventRepository;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.PlatformPlanResponse;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.Tier;
import com.felipebagarelli.gymmanager.platformplan.entity.BillingInterval;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscription;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscriptionStatus;
import com.felipebagarelli.gymmanager.platformplan.repository.PlatformSubscriptionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Plano da plataforma: quem pode assinar, checkout com teste, webhooks e cancelamento. */
class PlatformPlanServiceTest {

    private static final String EMAIL = "ana@example.com";
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-18T12:00:00Z"), ZoneId.of("America/Sao_Paulo"));

    private final List<PlatformSubscription> rows = new ArrayList<>();
    private final Set<String> events = new HashSet<>();
    private final AtomicLong ids = new AtomicLong(1);
    private StudentProfile student;
    private TrainerStudentRepository links;
    private PaymentProvider provider;
    private PlatformPlanService service;
    private PlatformWebhookService webhooks;

    @BeforeEach
    void setUp() {
        student = StudentProfile.builder().id(9L).name("Ana").birthDate(LocalDate.of(1995, 1, 1))
                .user(User.builder().email(EMAIL).role(Role.STUDENT).build()).build();
        StudentProfileRepository students = mock(StudentProfileRepository.class);
        when(students.findByUserEmail(EMAIL)).thenReturn(Optional.of(student));
        links = mock(TrainerStudentRepository.class);
        when(links.findByStudentId(anyLong())).thenReturn(Optional.empty());

        PlatformSubscriptionRepository repo = mock(PlatformSubscriptionRepository.class);
        when(repo.save(any(PlatformSubscription.class))).thenAnswer(i -> {
            PlatformSubscription s = i.getArgument(0);
            if (s.getId() == null) s.setId(ids.getAndIncrement());
            if (!rows.contains(s)) rows.add(s);
            return s;
        });
        when(repo.findFirstByStudentIdOrderByIdDesc(anyLong())).thenAnswer(i -> rows.isEmpty() ? Optional.empty() : Optional.of(rows.getLast()));
        when(repo.findByStripeSubscriptionId(anyString())).thenAnswer(i ->
                rows.stream().filter(r -> i.getArgument(0).equals(r.getStripeSubscriptionId())).findFirst());
        when(repo.findById(anyLong())).thenAnswer(i -> rows.stream().filter(r -> r.getId().equals(i.getArgument(0))).findFirst());
        when(repo.existsByStudentIdAndTrialEndIsNotNull(anyLong())).thenAnswer(i -> rows.stream().anyMatch(r -> r.getTrialEnd() != null));

        provider = mock(PaymentProvider.class);
        when(provider.createPlatformCheckout(any())).thenReturn(new CheckoutSession("cs_1", "https://checkout.stripe.test/cs_1"));

        BillingEventRepository eventRepo = mock(BillingEventRepository.class);
        when(eventRepo.existsById(anyString())).thenAnswer(i -> events.contains((String) i.getArgument(0)));
        when(eventRepo.save(any(BillingEvent.class))).thenAnswer(i -> {
            events.add(((BillingEvent) i.getArgument(0)).getStripeEventId());
            return i.getArgument(0);
        });

        service = new PlatformPlanService(repo, students, links, provider, 1990, 14990, 7, true, "https://api.test/", clock);
        webhooks = new PlatformWebhookService(provider, eventRepo, repo);
    }

    private void webhook(String id, Type type, String status, LocalDateTime trialEnd, Boolean cancel) {
        when(provider.parsePlatformWebhook(eq(id), any())).thenReturn(
                new PlatformBillingNotification(id, type, rows.getLast().getId(), "sub_p", status,
                        LocalDateTime.of(2026, 11, 18, 12, 0), trialEnd, cancel));
        webhooks.handle(id, "sig");
    }

    @Test
    void salesClosed_untilEnabled() {
        PlatformPlanService closed = new PlatformPlanService(mock(PlatformSubscriptionRepository.class),
                mockStudents(), links, provider, 1990, 14990, 7, false, "https://api.test", clock);
        assertThat(closed.status(EMAIL).canSubscribe()).isFalse();
        assertThat(closed.status(EMAIL).unavailableReason()).contains("em breve");
        assertThatThrownBy(() -> closed.subscribe(BillingInterval.MONTHLY, EMAIL)).isInstanceOf(ConflictException.class);
        verify(provider, never()).createPlatformCheckout(any());
    }

    private StudentProfileRepository mockStudents() {
        StudentProfileRepository students = mock(StudentProfileRepository.class);
        when(students.findByUserEmail(EMAIL)).thenReturn(Optional.of(student));
        return students;
    }

    @Test
    void newIndependentAdult_isFree_canSubscribe_withTrial() {
        PlatformPlanResponse status = service.status(EMAIL);
        assertThat(status.tier()).isEqualTo(Tier.FREE);
        assertThat(status.aiWorkoutsPerMonth()).isEqualTo(1);
        assertThat(status.canSubscribe()).isTrue();
        assertThat(status.offer().monthlyCents()).isEqualTo(1990);
        assertThat(status.offer().yearlyCents()).isEqualTo(14990);
        assertThat(status.offer().trialAvailable()).isTrue();
        assertThat(status.subscription()).isNull();
    }

    @Test
    void subscribe_usesServerPrice_andTrialOnlyTheFirstTime() {
        assertThat(service.subscribe(BillingInterval.YEARLY, EMAIL).url()).isEqualTo("https://checkout.stripe.test/cs_1");
        ArgumentCaptor<PlatformCheckoutRequest> request = ArgumentCaptor.forClass(PlatformCheckoutRequest.class);
        verify(provider).createPlatformCheckout(request.capture());
        assertThat(request.getValue().priceCents()).isEqualTo(14990);
        assertThat(request.getValue().yearly()).isTrue();
        assertThat(request.getValue().trialDays()).isEqualTo(7);
        assertThat(request.getValue().successUrl()).isEqualTo("https://api.test/checkout/retorno?status=ok");
        assertThat(rows.getLast().getStatus()).isEqualTo(PlatformSubscriptionStatus.PENDING);
        // checkout criado nao e Pro: so o webhook confirma
        assertThat(service.status(EMAIL).tier()).isEqualTo(Tier.FREE);

        // teste comecou e depois cancelou: sem novo teste
        webhook("evt_1", Type.SUBSCRIPTION_UPDATED, "trialing", LocalDateTime.of(2026, 10, 25, 12, 0), false);
        assertThat(service.status(EMAIL).tier()).isEqualTo(Tier.PRO);
        webhook("evt_2", Type.SUBSCRIPTION_CANCELED, "canceled", null, null);
        assertThat(service.status(EMAIL).tier()).isEqualTo(Tier.FREE);
        assertThat(service.status(EMAIL).offer().trialAvailable()).isFalse();

        service.subscribe(BillingInterval.MONTHLY, EMAIL);
        ArgumentCaptor<PlatformCheckoutRequest> second = ArgumentCaptor.forClass(PlatformCheckoutRequest.class);
        verify(provider, org.mockito.Mockito.times(2)).createPlatformCheckout(second.capture());
        assertThat(second.getValue().trialDays()).isZero();
        assertThat(second.getValue().priceCents()).isEqualTo(1990);
    }

    @Test
    void whoCannotSubscribe() {
        when(links.findByStudentId(anyLong())).thenReturn(Optional.of(
                TrainerStudent.builder().student(student).status(TrainerStudentStatus.ACTIVE).build()));
        assertThat(service.status(EMAIL).canSubscribe()).isFalse();
        assertThatThrownBy(() -> service.subscribe(BillingInterval.MONTHLY, EMAIL))
                .isInstanceOf(ConflictException.class).hasMessageContaining("personal");

        when(links.findByStudentId(anyLong())).thenReturn(Optional.empty());
        student.setBirthDate(LocalDate.of(2010, 1, 1));
        assertThatThrownBy(() -> service.subscribe(BillingInterval.MONTHLY, EMAIL))
                .isInstanceOf(ConflictException.class).hasMessageContaining("responsável");
        verify(provider, never()).createPlatformCheckout(any());
    }

    @Test
    void cannotSubscribeTwice_butAPendingCheckoutIsReplaced() {
        service.subscribe(BillingInterval.MONTHLY, EMAIL);
        PlatformSubscription first = rows.getLast();
        service.subscribe(BillingInterval.YEARLY, EMAIL);
        assertThat(first.getStatus()).isEqualTo(PlatformSubscriptionStatus.CANCELED);

        webhook("evt_a", Type.CHECKOUT_COMPLETED, null, null, null);
        assertThatThrownBy(() -> service.subscribe(BillingInterval.MONTHLY, EMAIL))
                .isInstanceOf(ConflictException.class).hasMessageContaining("já tem");
    }

    @Test
    void webhooks_areIdempotent_paymentFailureRemovesPro_andCanceledStaysCanceled() {
        service.subscribe(BillingInterval.MONTHLY, EMAIL);
        webhook("evt_1", Type.CHECKOUT_COMPLETED, null, null, null);
        assertThat(rows.getLast().getStripeSubscriptionId()).isEqualTo("sub_p");
        assertThat(service.status(EMAIL).tier()).isEqualTo(Tier.PRO);

        webhook("evt_2", Type.PAYMENT_FAILED, null, null, null);
        assertThat(service.status(EMAIL).tier()).isEqualTo(Tier.FREE);
        assertThat(rows.getLast().getStatus()).isEqualTo(PlatformSubscriptionStatus.PAST_DUE);

        webhook("evt_3", Type.PAYMENT_SUCCEEDED, null, null, null);
        assertThat(rows.getLast().getStatus()).isEqualTo(PlatformSubscriptionStatus.ACTIVE);
        assertThat(rows.getLast().getCurrentPeriodEnd()).isEqualTo(LocalDateTime.of(2026, 11, 18, 12, 0));

        // repetido: ignorado
        rows.getLast().setStatus(PlatformSubscriptionStatus.PAST_DUE);
        webhooks.handle("evt_3", "sig");
        assertThat(rows.getLast().getStatus()).isEqualTo(PlatformSubscriptionStatus.PAST_DUE);

        webhook("evt_4", Type.SUBSCRIPTION_CANCELED, "canceled", null, null);
        webhook("evt_5", Type.SUBSCRIPTION_UPDATED, "active", null, null);
        assertThat(rows.getLast().getStatus()).isEqualTo(PlatformSubscriptionStatus.CANCELED);
    }

    @Test
    void cancelAtPeriodEnd_keepsPro_andCanBeUndone() {
        service.subscribe(BillingInterval.MONTHLY, EMAIL);
        webhook("evt_1", Type.SUBSCRIPTION_UPDATED, "active", null, false);

        PlatformPlanResponse canceled = service.cancel(EMAIL);
        verify(provider).setPlatformCancelAtPeriodEnd("sub_p", true);
        assertThat(canceled.tier()).isEqualTo(Tier.PRO);
        assertThat(canceled.subscription().cancelAtPeriodEnd()).isTrue();

        PlatformPlanResponse resumed = service.resume(EMAIL);
        verify(provider).setPlatformCancelAtPeriodEnd("sub_p", false);
        assertThat(resumed.subscription().cancelAtPeriodEnd()).isFalse();

        assertThatThrownBy(() -> service.regularize(EMAIL)).isInstanceOf(ConflictException.class);
    }
}
