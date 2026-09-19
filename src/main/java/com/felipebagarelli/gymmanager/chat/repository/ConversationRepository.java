package com.felipebagarelli.gymmanager.chat.repository;

import com.felipebagarelli.gymmanager.chat.entity.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, Long> {
    Optional<Conversation> findByTrainerStudentId(Long trainerStudentId);
}
