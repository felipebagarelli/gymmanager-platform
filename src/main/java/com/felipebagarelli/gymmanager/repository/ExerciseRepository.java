package com.felipebagarelli.gymmanager.repository;

import com.felipebagarelli.gymmanager.entity.Exercises;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExerciseRepository extends JpaRepository<Exercises, Long> {
    /** Catalogo comum + exercicios do personal. */
    List<Exercises> findByTrainerIsNullOrTrainerIdOrderByNameAsc(Long trainerId);

    List<Exercises> findByTrainerIsNullOrderByNameAsc();

}