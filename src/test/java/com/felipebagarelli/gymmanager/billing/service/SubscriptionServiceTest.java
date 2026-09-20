package com.felipebagarelli.gymmanager.billing.service;

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
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.security.access.AccessDeniedException;

import java.math.BigDecimal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SubscriptionServiceTest {

    private static final String EMAIL = "aluno@example.com";

    @Mock
    private PaymentProvider provider;
    @Mock
    private SubscriptionRepository subscriptionRepository;
    @Mock
    private PlanRepository planRepository;
    @Mock
    private TrainerPayoutAccountRepository accountRepository;
    @Mock
    private StudentProfileRepository studentRepository;
    @Mock
    private TrainerProfileRepository trainerRepository;
    @Mock
    private TrainerStudentRepository linkRepository;

    private SubscriptionService service;
    private StudentProfile student;
    private TrainerProfile trainer;
    private Plan plan;

    @BeforeEach
    void setUp() {
        service = new SubscriptionService(provider, subscriptionRepository, planRepository, accountRepository,
                studentRepository, trainerRepository, linkRepository, new BigDecimal("10"), "http://app/");
        student = StudentProfile.builder().id(1L).name("Ana").active(true).build();
        trainer = TrainerProfile.builder().id(2L).build();
        plan = Plan.builder().id(3L).trainer(trainer).name("Mensal").priceCents(15000).active(true).build();
        when(studentRepository.findByUserEmail(EMAIL)).thenReturn(Optional.of(student));
        when(planRepository.findById(3L)).thenReturn(Optional.of(plan));
        when(linkRepository.findByStudentId(1L)).thenReturn(Optional.of(
                TrainerStudent.builder().trainer(trainer).student(student).status(TrainerStudentStatus.ACTIVE).build()));
        when(accountRepository.findByTrainerId(2L)).thenReturn(Optional.of(
                TrainerPayoutAccount.builder().stripeAccountId("acct_1").chargesEnabled(true).build()));
        when(subscriptionRepository.findFirstByStudentIdOrderByIdDesc(1L)).thenReturn(Optional.empty());
        when(subscriptionRepository.save(any())).thenAnswer(inv -> {
            Subscription s = inv.getArgument(0);
            if (s.getId() == null) s.setId(99L);
            return s;
        });
        when(provider.createCheckout(any())).thenReturn(new CheckoutSession("cs_1", "https://checkout/x"));
    }

    @Test
    void subscribe_createsPendingAndSendsFeeToProvider() {
        var response = service.subscribe(3L, EMAIL);

        assertThat(response.url()).isEqualTo("https://checkout/x");
        ArgumentCaptor<CheckoutRequest> captor = ArgumentCaptor.forClass(CheckoutRequest.class);
        verify(provider).createCheckout(captor.capture());
        assertThat(captor.getValue().platformFeePercent()).isEqualByComparingTo("10");
        assertThat(captor.getValue().accountId()).isEqualTo("acct_1");
        assertThat(captor.getValue().priceCents()).isEqualTo(15000);
        assertThat(captor.getValue().localSubscriptionId()).isEqualTo(99L);
        assertThat(captor.getValue().successUrl()).startsWith("http://app/assinatura");
    }

    @Test
    void subscribe_planOfAnotherTrainer_isDenied() {
        plan.setTrainer(TrainerProfile.builder().id(77L).build());

        assertThatThrownBy(() -> service.subscribe(3L, EMAIL)).isInstanceOf(AccessDeniedException.class);
        verify(provider, never()).createCheckout(any());
    }

    @Test
    void subscribe_inactivePlan_isDenied() {
        plan.setActive(false);
        assertThatThrownBy(() -> service.subscribe(3L, EMAIL)).isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void subscribe_whenAlreadyActiveOrPastDue_conflicts() {
        Subscription active = Subscription.builder().id(5L).status(SubscriptionStatus.PAST_DUE).build();
        when(subscriptionRepository.findFirstByStudentIdOrderByIdDesc(1L)).thenReturn(Optional.of(active));

        assertThatThrownBy(() -> service.subscribe(3L, EMAIL)).isInstanceOf(ConflictException.class);
    }

    @Test
    void subscribe_trainerWithoutPayoutAccount_conflicts() {
        when(accountRepository.findByTrainerId(2L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.subscribe(3L, EMAIL)).isInstanceOf(ConflictException.class);
    }

    @Test
    void cancel_callsProviderAndMarksCanceled() {
        Subscription active = Subscription.builder().id(5L).status(SubscriptionStatus.ACTIVE)
                .stripeSubscriptionId("sub_1").trainer(trainer).plan(plan).student(student).build();
        when(subscriptionRepository.findFirstByStudentIdOrderByIdDesc(1L)).thenReturn(Optional.of(active));

        var response = service.cancel(EMAIL);

        verify(provider).cancelSubscription("acct_1", "sub_1");
        assertThat(response.status()).isEqualTo(SubscriptionStatus.CANCELED);
    }
}
