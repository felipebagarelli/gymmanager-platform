package com.felipebagarelli.gymmanager.billing.service;

import com.felipebagarelli.gymmanager.billing.entity.SubscriptionStatus;
import com.felipebagarelli.gymmanager.billing.repository.SubscriptionRepository;
import com.felipebagarelli.gymmanager.exception.PaymentRequiredException;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.springframework.stereotype.Component;

/**
 * Bloqueia treinos e chat do aluno quando a ultima assinatura dele esta em atraso.
 * Aluno sem assinatura (cadastrado direto pelo personal) nao e afetado.
 */
@Component
public class BillingAccessGuard {

    static final String MESSAGE = "Sua mensalidade está em atraso. Regularize o pagamento para voltar a treinar.";

    private final SubscriptionRepository subscriptionRepository;
    private final StudentProfileRepository studentProfileRepository;

    public BillingAccessGuard(SubscriptionRepository subscriptionRepository,
                              StudentProfileRepository studentProfileRepository) {
        this.subscriptionRepository = subscriptionRepository;
        this.studentProfileRepository = studentProfileRepository;
    }

    public void assertStudentNotBlocked(Long studentId) {
        boolean blocked = subscriptionRepository.findFirstByStudentIdOrderByIdDesc(studentId)
                .map(subscription -> subscription.getStatus() == SubscriptionStatus.PAST_DUE)
                .orElse(false);
        if (blocked) {
            throw new PaymentRequiredException(MESSAGE);
        }
    }

    public void assertStudentNotBlockedByEmail(String email) {
        studentProfileRepository.findByUserEmail(email)
                .ifPresent(student -> assertStudentNotBlocked(student.getId()));
    }
}
