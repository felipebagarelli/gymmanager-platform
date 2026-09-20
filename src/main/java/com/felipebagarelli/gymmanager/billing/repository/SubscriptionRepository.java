package com.felipebagarelli.gymmanager.billing.repository;

import com.felipebagarelli.gymmanager.billing.entity.Subscription;
import com.felipebagarelli.gymmanager.billing.entity.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {
    Optional<Subscription> findFirstByStudentIdOrderByIdDesc(Long studentId);

    List<Subscription> findByTrainerIdOrderByIdDesc(Long trainerId);

    Optional<Subscription> findByStripeSubscriptionId(String stripeSubscriptionId);

    boolean existsByStudentIdAndStatus(Long studentId, SubscriptionStatus status);

    boolean existsByStudentIdAndStatusIn(Long studentId, List<SubscriptionStatus> statuses);
}
