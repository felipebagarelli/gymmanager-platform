package com.felipebagarelli.gymmanager.ai.repository;

import com.felipebagarelli.gymmanager.ai.entity.AiMessage;
import com.felipebagarelli.gymmanager.ai.entity.AiRole;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface AiMessageRepository extends JpaRepository<AiMessage, Long> {

    /** Mais recentes primeiro (o service reordena). */
    List<AiMessage> findByStudentIdOrderByIdDesc(Long studentId, Pageable pageable);

    long countByStudentIdAndRoleAndCreatedAtGreaterThanEqual(Long studentId, AiRole role, LocalDateTime since);
}
