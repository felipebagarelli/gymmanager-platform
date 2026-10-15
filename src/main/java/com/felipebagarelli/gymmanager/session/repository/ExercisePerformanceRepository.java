package com.felipebagarelli.gymmanager.session.repository;

import com.felipebagarelli.gymmanager.session.entity.ExercisePerformance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExercisePerformanceRepository extends JpaRepository<ExercisePerformance, Long> {
    List<ExercisePerformance> findBySessionIdOrderByIdAsc(Long sessionId);
    boolean existsByWorkoutExerciseId(Long workoutExerciseId);
}
