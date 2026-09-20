package com.felipebagarelli.gymmanager.billing.service;

import com.felipebagarelli.gymmanager.billing.entity.Subscription;
import com.felipebagarelli.gymmanager.billing.entity.SubscriptionStatus;
import com.felipebagarelli.gymmanager.billing.entity.TrainerPayoutAccount;
import com.felipebagarelli.gymmanager.billing.provider.BillingNotification;
import com.felipebagarelli.gymmanager.billing.provider.BillingNotification.Type;
import com.felipebagarelli.gymmanager.billing.provider.InvalidWebhookException;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.repository.BillingEventRepository;
import com.felipebagarelli.gymmanager.billing.repository.SubscriptionRepository;
import com.felipebagarelli.gymmanager.billing.repository.TrainerPayoutAccountRepository;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class BillingWebhookServiceTest {

    @Mock
    private PaymentProvider provider;
    @Mock
    private BillingEventRepository eventRepository;
    @Mock
    private SubscriptionRepository subscriptionRepository;
    @Mock
    private TrainerPayoutAccountRepository accountRepository;

    private BillingWebhookService service;
    private Subscription subscription;

    @BeforeEach
    void setUp() {
        service = new BillingWebhookService(provider, eventRepository, subscriptionRepository, accountRepository);
        subscription = Subscription.builder().id(1L).status(SubscriptionStatus.PENDING)
                .createdAt(LocalDateTime.now()).updatedAt(LocalDateTime.now()).build();
        when(subscriptionRepository.findById(1L)).thenReturn(Optional.of(subscription));
        when(subscriptionRepository.findByStripeSubscriptionId("sub_1")).thenReturn(Optional.of(subscription));
    }

    private void event(Type type, Long localId, String externalId) {
        when(provider.parseWebhook("p", "s"))
                .thenReturn(new BillingNotification("evt_1", type, localId, externalId, null, null, false));
    }

    @Test
    void checkoutCompleted_activatesAndStoresExternalId() {
        event(Type.CHECKOUT_COMPLETED, 1L, "sub_1");

        service.handle("p", "s");

        assertThat(subscription.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        assertThat(subscription.getStripeSubscriptionId()).isEqualTo("sub_1");
        verify(eventRepository).save(any());
    }

    @Test
    void paymentFailed_marksPastDue_andPaymentSucceededRecovers() {
        subscription.setStatus(SubscriptionStatus.ACTIVE);
        event(Type.PAYMENT_FAILED, null, "sub_1");
        service.handle("p", "s");
        assertThat(subscription.getStatus()).isEqualTo(SubscriptionStatus.PAST_DUE);

        when(provider.parseWebhook("p2", "s")).thenReturn(new BillingNotification("evt_2", Type.PAYMENT_SUCCEEDED,
                null, "sub_1", LocalDateTime.of(2026, 10, 1, 0, 0), null, false));
        service.handle("p2", "s");
        assertThat(subscription.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        assertThat(subscription.getCurrentPeriodEnd()).isEqualTo(LocalDateTime.of(2026, 10, 1, 0, 0));
    }

    @Test
    void canceledSubscription_isNotReactivatedByLateEvents() {
        subscription.setStatus(SubscriptionStatus.CANCELED);
        event(Type.PAYMENT_SUCCEEDED, null, "sub_1");

        service.handle("p", "s");

        assertThat(subscription.getStatus()).isEqualTo(SubscriptionStatus.CANCELED);
    }

    @Test
    void duplicatedEvent_isIgnored() {
        subscription.setStatus(SubscriptionStatus.ACTIVE);
        event(Type.PAYMENT_FAILED, null, "sub_1");
        when(eventRepository.existsById("evt_1")).thenReturn(true);

        service.handle("p", "s");

        assertThat(subscription.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        verify(eventRepository, never()).save(any());
    }

    @Test
    void unknownSubscription_throwsSoProviderRetries_andEventIsNotRecorded() {
        event(Type.PAYMENT_FAILED, null, "sub_desconhecida");
        when(subscriptionRepository.findByStripeSubscriptionId("sub_desconhecida")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.handle("p", "s")).isInstanceOf(ResourceNotFoundException.class);
        verify(eventRepository, never()).save(any());
    }

    @Test
    void accountUpdated_enablesCharges() {
        TrainerPayoutAccount account = TrainerPayoutAccount.builder().stripeAccountId("acct_1").build();
        when(accountRepository.findByStripeAccountId("acct_1")).thenReturn(Optional.of(account));
        when(provider.parseWebhook("p", "s")).thenReturn(
                new BillingNotification("evt_9", Type.ACCOUNT_UPDATED, null, null, null, "acct_1", true));

        service.handle("p", "s");

        assertThat(account.isChargesEnabled()).isTrue();
    }

    @Test
    void invalidSignature_propagatesAndChangesNothing() {
        when(provider.parseWebhook("p", "ruim")).thenThrow(new InvalidWebhookException("x"));

        assertThatThrownBy(() -> service.handle("p", "ruim")).isInstanceOf(InvalidWebhookException.class);
        verify(subscriptionRepository, never()).save(any());
    }
}
