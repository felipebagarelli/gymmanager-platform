package com.felipebagarelli.gymmanager.onboarding.repository;

import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface TrainingProfileRepository extends JpaRepository<TrainingProfile, Long> {
    Optional<TrainingProfile> findByStudentId(Long studentId);
}
