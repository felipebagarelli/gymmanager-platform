package com.felipebagarelli.gymmanager.platformplan.repository;

import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscription;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PlatformSubscriptionRepository extends JpaRepository<PlatformSubscription, Long> {
    Optional<PlatformSubscription> findFirstByStudentIdOrderByIdDesc(Long studentId);

    Optional<PlatformSubscription> findByStripeSubscriptionId(String stripeSubscriptionId);

    /** Ja usou o periodo de teste alguma vez (o teste so vale na primeira assinatura). */
    boolean existsByStudentIdAndTrialEndIsNotNull(Long studentId);
}
