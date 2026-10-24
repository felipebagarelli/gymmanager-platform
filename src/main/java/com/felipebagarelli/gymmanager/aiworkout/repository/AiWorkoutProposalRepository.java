package com.felipebagarelli.gymmanager.aiworkout.repository;

import com.felipebagarelli.gymmanager.aiworkout.entity.AiWorkoutProposal;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Optional;

public interface AiWorkoutProposalRepository extends JpaRepository<AiWorkoutProposal, Long> {
    long countByStudentIdAndCreatedAtGreaterThanEqual(Long studentId, LocalDateTime since);

    Optional<AiWorkoutProposal> findByIdAndStudentId(Long id, Long studentId);

    void deleteByStudentId(Long studentId);
}
