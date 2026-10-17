package com.felipebagarelli.gymmanager.account.repository;

import com.felipebagarelli.gymmanager.account.entity.LegalAcceptance;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LegalAcceptanceRepository extends JpaRepository<LegalAcceptance, Long> {
    List<LegalAcceptance> findByUserIdOrderByAcceptedAtAsc(Long userId);
}
