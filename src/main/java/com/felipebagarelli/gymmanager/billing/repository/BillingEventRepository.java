package com.felipebagarelli.gymmanager.billing.repository;

import com.felipebagarelli.gymmanager.billing.entity.BillingEvent;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BillingEventRepository extends JpaRepository<BillingEvent, String> {
}
