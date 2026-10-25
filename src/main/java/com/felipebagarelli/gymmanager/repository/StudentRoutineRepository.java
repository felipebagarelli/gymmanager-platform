package com.felipebagarelli.gymmanager.repository;

import com.felipebagarelli.gymmanager.entity.StudentRoutine;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StudentRoutineRepository extends JpaRepository<StudentRoutine, Long> {
}
