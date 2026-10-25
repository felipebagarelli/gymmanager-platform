package com.felipebagarelli.gymmanager.billing.repository;

import com.felipebagarelli.gymmanager.billing.entity.Plan;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PlanRepository extends JpaRepository<Plan, Long> {
    List<Plan> findByTrainerIdOrderByPriceCentsAsc(Long trainerId);

    List<Plan> findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(Long trainerId);
    java.util.Optional<Plan> findByInviteCode(String inviteCode);
}
