package com.felipebagarelli.gymmanager.repository;

import com.felipebagarelli.gymmanager.entity.Exercises;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ExerciseRepository extends JpaRepository<Exercises, Long> {

}