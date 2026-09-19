package com.felipebagarelli.gymmanager.student.repository;

import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TrainerStudentRepository extends JpaRepository<TrainerStudent, Long> {
    List<TrainerStudent> findByTrainerId(Long trainerId);
    Optional<TrainerStudent> findByStudentId(Long studentId);
    List<TrainerStudent> findByTrainerUserEmail(String email);
    List<TrainerStudent> findByStudentUserEmail(String email);
}
