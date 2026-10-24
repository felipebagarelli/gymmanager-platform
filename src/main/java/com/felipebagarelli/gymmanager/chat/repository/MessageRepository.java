package com.felipebagarelli.gymmanager.chat.repository;

import com.felipebagarelli.gymmanager.chat.entity.Message;
import com.felipebagarelli.gymmanager.chat.entity.MessageSender;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MessageRepository extends JpaRepository<Message, Long> {

    /** As mais recentes primeiro (o service reordena). */
    List<Message> findByConversationIdOrderByIdDesc(Long conversationId, Pageable pageable);

    List<Message> findByConversationIdAndIdGreaterThanOrderByIdAsc(Long conversationId, Long afterId, Pageable pageable);

    Optional<Message> findFirstByConversationIdOrderByIdDesc(Long conversationId);

    void deleteByConversationId(Long conversationId);

    long countByConversationIdAndIdGreaterThanAndSenderRoleNot(Long conversationId, Long afterId, MessageSender sender);
}
