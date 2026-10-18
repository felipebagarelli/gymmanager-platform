package com.felipebagarelli.gymmanager.platformplan.service;

import com.felipebagarelli.gymmanager.billing.entity.BillingEvent;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.provider.PlatformBillingNotification;
import com.felipebagarelli.gymmanager.billing.repository.BillingEventRepository;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscription;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscriptionStatus;
import com.felipebagarelli.gymmanager.platformplan.repository.PlatformSubscriptionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

/**
 * Unica porta pela qual o plano da plataforma muda por causa do provedor. Cada evento e aplicado
 * uma vez (idempotencia pelo id do evento, na mesma tabela da cobranca dos personais).
 */
@Service
public class PlatformWebhookService {

    private final PaymentProvider paymentProvider;
    private final BillingEventRepository eventRepository;
    private final PlatformSubscriptionRepository repository;

    public PlatformWebhookService(PaymentProvider paymentProvider,
                                  BillingEventRepository eventRepository,
                                  PlatformSubscriptionRepository repository) {
        this.paymentProvider = paymentProvider;
        this.eventRepository = eventRepository;
        this.repository = repository;
    }

    @Transactional
    public void handle(String payload, String signature) {
        PlatformBillingNotification event = paymentProvider.parsePlatformWebhook(payload, signature);
        if (event.eventId() == null || eventRepository.existsById(event.eventId())) {
            return;
        }
        apply(event);
        eventRepository.save(BillingEvent.builder().stripeEventId(event.eventId()).receivedAt(LocalDateTime.now()).build());
    }

    void apply(PlatformBillingNotification event) {
        switch (event.type()) {
            case CHECKOUT_COMPLETED -> {
                PlatformSubscription s = find(event);
                if (s.getStripeSubscriptionId() == null) s.setStripeSubscriptionId(event.externalSubscriptionId());
                // o status certo (teste ou ativa) chega no customer.subscription.*; aqui so sai do PENDING
                if (s.getStatus() == PlatformSubscriptionStatus.PENDING) s.setStatus(PlatformSubscriptionStatus.ACTIVE);
                save(s);
            }
            case SUBSCRIPTION_UPDATED -> {
                PlatformSubscription s = find(event);
                if (s.getStripeSubscriptionId() == null) s.setStripeSubscriptionId(event.externalSubscriptionId());
                change(s, toStatus(event.status()));
                if (event.periodEnd() != null) s.setCurrentPeriodEnd(event.periodEnd());
                if (event.trialEnd() != null) s.setTrialEnd(event.trialEnd());
                if (event.cancelAtPeriodEnd() != null) s.setCancelAtPeriodEnd(event.cancelAtPeriodEnd());
                save(s);
            }
            case PAYMENT_SUCCEEDED -> {
                PlatformSubscription s = find(event);
                change(s, PlatformSubscriptionStatus.ACTIVE);
                if (event.periodEnd() != null) s.setCurrentPeriodEnd(event.periodEnd());
                save(s);
            }
            case PAYMENT_FAILED -> {
                PlatformSubscription s = find(event);
                change(s, PlatformSubscriptionStatus.PAST_DUE);
                save(s);
            }
            case SUBSCRIPTION_CANCELED -> {
                PlatformSubscription s = find(event);
                s.setStatus(PlatformSubscriptionStatus.CANCELED);
                save(s);
            }
            case IGNORED -> {
            }
        }
    }

    private static PlatformSubscriptionStatus toStatus(String status) {
        if (status == null) return null;
        return switch (status) {
            case "trialing" -> PlatformSubscriptionStatus.TRIALING;
            case "active" -> PlatformSubscriptionStatus.ACTIVE;
            case "past_due" -> PlatformSubscriptionStatus.PAST_DUE;
            case "canceled" -> PlatformSubscriptionStatus.CANCELED;
            default -> null;
        };
    }

    /** Cancelada e definitiva: eventos atrasados nao a reativam. */
    private static void change(PlatformSubscription s, PlatformSubscriptionStatus status) {
        if (status == null || s.getStatus() == PlatformSubscriptionStatus.CANCELED) return;
        s.setStatus(status);
    }

    private void save(PlatformSubscription s) {
        s.setUpdatedAt(LocalDateTime.now());
        repository.save(s);
    }

    /** Pela assinatura externa ou pelo id local nos metadados. 404 faz o provedor tentar de novo. */
    private PlatformSubscription find(PlatformBillingNotification event) {
        Optional<PlatformSubscription> byExternal = event.externalSubscriptionId() == null
                ? Optional.empty()
                : repository.findByStripeSubscriptionId(event.externalSubscriptionId());
        return byExternal
                .or(() -> event.localSubscriptionId() == null ? Optional.empty() : repository.findById(event.localSubscriptionId()))
                .orElseThrow(() -> new ResourceNotFoundException("Assinatura não encontrada!"));
    }
}
