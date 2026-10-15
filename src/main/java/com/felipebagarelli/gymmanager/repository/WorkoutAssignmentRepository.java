package com.felipebagarelli.gymmanager.repository;

import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface WorkoutAssignmentRepository extends JpaRepository<WorkoutAssignment, Long> {
    List<WorkoutAssignment> findByStudentIdAndStatus(Long studentId, WorkoutAssignmentStatus status);
    Optional<WorkoutAssignment> findByWorkoutIdAndStudentIdAndStatus(Long workoutId, Long studentId, WorkoutAssignmentStatus status);
    Optional<WorkoutAssignment> findByWorkoutIdAndStudentUserEmailAndStatus(Long workoutId, String email, WorkoutAssignmentStatus status);
    boolean existsByWorkoutId(Long workoutId);
    List<WorkoutAssignment> findByWorkoutIdAndStatusOrderByStudentNameAsc(Long workoutId, WorkoutAssignmentStatus status);
    long countByWorkoutIdAndStatus(Long workoutId, WorkoutAssignmentStatus status);
    boolean existsByWorkoutIdAndStudentUserEmail(Long workoutId, String email);
}
