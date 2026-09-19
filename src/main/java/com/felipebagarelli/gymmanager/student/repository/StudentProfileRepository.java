package com.felipebagarelli.gymmanager.student.repository;

import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface StudentProfileRepository extends JpaRepository<StudentProfile, Long> {
    Optional<StudentProfile> findByUserEmail(String email);
}
