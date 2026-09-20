package com.felipebagarelli.gymmanager.billing.service;

import com.felipebagarelli.gymmanager.billing.entity.Subscription;
import com.felipebagarelli.gymmanager.billing.entity.SubscriptionStatus;
import com.felipebagarelli.gymmanager.billing.repository.SubscriptionRepository;
import com.felipebagarelli.gymmanager.exception.PaymentRequiredException;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BillingAccessGuardTest {

    @Mock
    private SubscriptionRepository subscriptionRepository;
    @Mock
    private StudentProfileRepository studentProfileRepository;
    @InjectMocks
    private BillingAccessGuard guard;

    private void latest(SubscriptionStatus status) {
        when(subscriptionRepository.findFirstByStudentIdOrderByIdDesc(1L))
                .thenReturn(Optional.of(Subscription.builder().status(status).build()));
    }

    @Test
    void pastDue_blocksWith402Exception() {
        latest(SubscriptionStatus.PAST_DUE);
        assertThatThrownBy(() -> guard.assertStudentNotBlocked(1L)).isInstanceOf(PaymentRequiredException.class);
    }

    @Test
    void activePendingCanceledOrNoSubscription_doNotBlock() {
        for (SubscriptionStatus status : new SubscriptionStatus[]{SubscriptionStatus.ACTIVE,
                SubscriptionStatus.PENDING, SubscriptionStatus.CANCELED}) {
            latest(status);
            assertThatCode(() -> guard.assertStudentNotBlocked(1L)).doesNotThrowAnyException();
        }
        when(subscriptionRepository.findFirstByStudentIdOrderByIdDesc(1L)).thenReturn(Optional.empty());
        assertThatCode(() -> guard.assertStudentNotBlocked(1L)).doesNotThrowAnyException();
    }
}
