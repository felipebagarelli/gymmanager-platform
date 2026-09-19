package com.felipebagarelli.gymmanager.repository;


import com.felipebagarelli.gymmanager.entity.Workout;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface WorkoutRepository extends JpaRepository<Workout, Long> {
    List<Workout> findByMemberId (Long memberId);
}
