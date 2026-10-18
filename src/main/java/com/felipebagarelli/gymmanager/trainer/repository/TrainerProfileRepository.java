package com.felipebagarelli.gymmanager.trainer.repository;

import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TrainerProfileRepository extends JpaRepository<TrainerProfile, Long> {
    java.util.List<TrainerProfile> findByListedTrueOrderByDisplayNameAsc();

    Optional<TrainerProfile> findByUserEmail(String email);
}
