package com.felipebagarelli.gymmanager.billing.repository;

import com.felipebagarelli.gymmanager.billing.entity.TrainerPayoutAccount;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface TrainerPayoutAccountRepository extends JpaRepository<TrainerPayoutAccount, Long> {
    Optional<TrainerPayoutAccount> findByTrainerId(Long trainerId);

    Optional<TrainerPayoutAccount> findByStripeAccountId(String stripeAccountId);
}
