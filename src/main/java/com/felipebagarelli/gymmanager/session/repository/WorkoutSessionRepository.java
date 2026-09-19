package com.felipebagarelli.gymmanager.session.repository;

import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, Long> {
    List<WorkoutSession> findByAssignmentStudentIdOrderByStartedAtDesc(Long studentId);
    boolean existsByAssignmentIdAndFinishedAtIsNull(Long assignmentId);
}
