package com.felipebagarelli.gymmanager.onboarding.repository;

import com.felipebagarelli.gymmanager.onboarding.entity.HealthScreening;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface HealthScreeningRepository extends JpaRepository<HealthScreening, Long> {
    Optional<HealthScreening> findFirstByStudentIdOrderByAnsweredAtDescIdDesc(Long studentId);

    void deleteByStudentId(Long studentId);
}
