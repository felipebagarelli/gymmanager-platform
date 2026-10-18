package com.felipebagarelli.gymmanager.billing.service;

import com.felipebagarelli.gymmanager.billing.entity.BillingEvent;
import com.felipebagarelli.gymmanager.billing.entity.Subscription;
import com.felipebagarelli.gymmanager.billing.entity.SubscriptionStatus;
import com.felipebagarelli.gymmanager.billing.provider.BillingNotification;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.repository.BillingEventRepository;
import com.felipebagarelli.gymmanager.billing.repository.SubscriptionRepository;
import com.felipebagarelli.gymmanager.billing.repository.TrainerPayoutAccountRepository;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * Unica porta pela qual o estado da assinatura muda por causa do provedor. O evento so e
 * processado se a assinatura for valida, e uma unica vez (idempotencia por id do evento).
 */
@Service
public class BillingWebhookService {

    private final PaymentProvider paymentProvider;
    private final BillingEventRepository eventRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final TrainerPayoutAccountRepository accountRepository;
    private final TrainerStudentRepository trainerStudentRepository;

    public BillingWebhookService(PaymentProvider paymentProvider,
                                 BillingEventRepository eventRepository,
                                 SubscriptionRepository subscriptionRepository,
                                 TrainerPayoutAccountRepository accountRepository,
                                 TrainerStudentRepository trainerStudentRepository) {
        this.trainerStudentRepository = trainerStudentRepository;
        this.paymentProvider = paymentProvider;
        this.eventRepository = eventRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.accountRepository = accountRepository;
    }

    @Transactional
    public void handle(String payload, String signature) {
        BillingNotification event = paymentProvider.parseWebhook(payload, signature);
        if (event.eventId() == null || eventRepository.existsById(event.eventId())) {
            return;
        }
        apply(event);
        eventRepository.save(BillingEvent.builder()
                .stripeEventId(event.eventId()).receivedAt(LocalDateTime.now()).build());
    }

    private void apply(BillingNotification event) {
        switch (event.type()) {
            case CHECKOUT_COMPLETED -> {
                Subscription subscription = subscriptionRepository.findById(requireLocalId(event))
                        .orElseThrow(() -> new ResourceNotFoundException("Assinatura não encontrada!"));
                subscription.setStripeSubscriptionId(event.externalSubscriptionId());
                change(subscription, SubscriptionStatus.ACTIVE, null);
                // contratacao pelo hub: o pagamento confirmado ativa o vinculo com o personal
                if (subscription.getStudent() != null && subscription.getTrainer() != null) {
                    trainerStudentRepository.findByStudentId(subscription.getStudent().getId())
                            .filter(link -> link.pendingPayment()
                                    && link.getTrainer().getId().equals(subscription.getTrainer().getId()))
                            .ifPresent(link -> {
                                link.setStatus(TrainerStudentStatus.ACTIVE);
                                trainerStudentRepository.save(link);
                            });
                }
            }
            case PAYMENT_SUCCEEDED -> change(byExternalId(event), SubscriptionStatus.ACTIVE, event);
            case PAYMENT_FAILED -> change(byExternalId(event), SubscriptionStatus.PAST_DUE, null);
            case SUBSCRIPTION_CANCELED -> change(byExternalId(event), SubscriptionStatus.CANCELED, null);
            case ACCOUNT_UPDATED -> accountRepository.findByStripeAccountId(event.accountId()).ifPresent(account -> {
                account.setChargesEnabled(event.chargesEnabled());
                account.setUpdatedAt(LocalDateTime.now());
                accountRepository.save(account);
            });
            case IGNORED -> {
            }
        }
    }

    private Long requireLocalId(BillingNotification event) {
        if (event.localSubscriptionId() == null) {
            throw new ResourceNotFoundException("Assinatura não encontrada!");
        }
        return event.localSubscriptionId();
    }

    /** 404 faz o provedor tentar de novo (o evento pode chegar antes do checkout ser confirmado). */
    private Subscription byExternalId(BillingNotification event) {
        return subscriptionRepository.findByStripeSubscriptionId(event.externalSubscriptionId())
                .orElseThrow(() -> new ResourceNotFoundException("Assinatura não encontrada!"));
    }

    /** Assinatura cancelada e definitiva: eventos atrasados nao a reativam. */
    private void change(Subscription subscription, SubscriptionStatus status, BillingNotification periodSource) {
        if (subscription.getStatus() == SubscriptionStatus.CANCELED && status != SubscriptionStatus.CANCELED) {
            return;
        }
        subscription.setStatus(status);
        if (periodSource != null && periodSource.periodEnd() != null) {
            subscription.setCurrentPeriodEnd(periodSource.periodEnd());
        }
        subscription.setUpdatedAt(LocalDateTime.now());
        subscriptionRepository.save(subscription);
    }
}
