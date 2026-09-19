package com.felipebagarelli.gymmanager.repository;


import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface WorkoutExercisesRepository extends JpaRepository<WorkoutExercises, Long> {
    List<WorkoutExercises> findByWorkoutId(Long workoutId);
}
