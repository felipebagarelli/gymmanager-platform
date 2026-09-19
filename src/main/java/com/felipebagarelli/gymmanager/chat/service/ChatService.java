package com.felipebagarelli.gymmanager.chat.service;

import com.felipebagarelli.gymmanager.chat.dto.ConversationSummary;
import com.felipebagarelli.gymmanager.chat.dto.MessageResponse;
import com.felipebagarelli.gymmanager.chat.entity.Conversation;
import com.felipebagarelli.gymmanager.chat.entity.Message;
import com.felipebagarelli.gymmanager.chat.entity.MessageSender;
import com.felipebagarelli.gymmanager.chat.repository.ConversationRepository;
import com.felipebagarelli.gymmanager.chat.repository.MessageRepository;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

@Service
public class ChatService {

    static final int DEFAULT_LIMIT = 50;
    static final int MAX_LIMIT = 100;

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final TrainerStudentRepository trainerStudentRepository;

    public ChatService(ConversationRepository conversationRepository,
                       MessageRepository messageRepository,
                       TrainerStudentRepository trainerStudentRepository) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.trainerStudentRepository = trainerStudentRepository;
    }

    private MessageResponse toResponse(Message message) {
        return new MessageResponse(message.getId(), message.getConversation().getId(),
                message.getSenderRole(), message.getBody(), message.getCreatedAt());
    }

    private Conversation findConversation(Long id) {
        return conversationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Conversa não encontrada!"));
    }

    /** Lado do usuario autenticado na conversa; quem nao participa recebe 403. */
    private MessageSender sideOf(TrainerStudent link, String email) {
        if (link.getTrainer().getUser().getEmail().equalsIgnoreCase(email)) return MessageSender.TRAINER;
        if (link.getStudent().getUser().getEmail().equalsIgnoreCase(email)) return MessageSender.STUDENT;
        throw new AccessDeniedException("Você não participa desta conversa.");
    }

    /** So vinculo ACTIVE com aluno ativo pode enviar; nos demais casos o historico continua legivel. */
    private boolean canSend(TrainerStudent link) {
        return link.getStatus() == TrainerStudentStatus.ACTIVE && link.getStudent().isActive();
    }

    private Conversation getOrCreate(TrainerStudent link) {
        return conversationRepository.findByTrainerStudentId(link.getId())
                .orElseGet(() -> conversationRepository.save(Conversation.builder()
                        .trainerStudent(link)
                        .createdAt(LocalDateTime.now())
                        .build()));
    }

    private long unreadFor(Conversation conversation, MessageSender side) {
        Long lastRead = conversation.lastReadBy(side);
        return messageRepository.countByConversationIdAndIdGreaterThanAndSenderRoleNot(
                conversation.getId(), lastRead == null ? 0L : lastRead, side);
    }

    @Transactional
    public List<ConversationSummary> myConversations(String email) {
        List<TrainerStudent> links = new ArrayList<>(trainerStudentRepository.findByTrainerUserEmail(email));
        links.addAll(trainerStudentRepository.findByStudentUserEmail(email));

        List<ConversationSummary> summaries = new ArrayList<>();
        for (TrainerStudent link : links) {
            Conversation conversation = getOrCreate(link);
            MessageSender side = sideOf(link, email);
            MessageResponse last = messageRepository.findFirstByConversationIdOrderByIdDesc(conversation.getId())
                    .map(this::toResponse)
                    .orElse(null);
            summaries.add(new ConversationSummary(
                    conversation.getId(),
                    link.getStudent().getId(),
                    link.getStudent().getName(),
                    link.getTrainer().getId(),
                    link.getTrainer().getDisplayName(),
                    last,
                    unreadFor(conversation, side),
                    canSend(link)));
        }

        summaries.sort(Comparator.comparing(
                (ConversationSummary s) -> s.lastMessage() == null ? LocalDateTime.MIN : s.lastMessage().createdAt())
                .reversed());
        return summaries;
    }

    /**
     * Sem {@code after}: as {@code limit} mensagens mais recentes (ordem cronologica).
     * Com {@code after}: as mensagens posteriores a esse id (para polling).
     */
    public List<MessageResponse> messages(Long conversationId, Long after, Integer limit, String email) {
        Conversation conversation = findConversation(conversationId);
        sideOf(conversation.getTrainerStudent(), email);

        int size = limit == null ? DEFAULT_LIMIT : Math.max(1, Math.min(limit, MAX_LIMIT));
        List<Message> messages;
        if (after == null) {
            messages = new ArrayList<>(messageRepository
                    .findByConversationIdOrderByIdDesc(conversationId, PageRequest.of(0, size)));
            Collections.reverse(messages);
        } else {
            messages = messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(
                    conversationId, after, PageRequest.of(0, size));
        }
        return messages.stream().map(this::toResponse).toList();
    }

    @Transactional
    public MessageResponse send(Long conversationId, String body, String email) {
        Conversation conversation = findConversation(conversationId);
        TrainerStudent link = conversation.getTrainerStudent();
        MessageSender side = sideOf(link, email);

        if (!canSend(link)) {
            throw new ConflictException("Esta conversa está encerrada: só é possível ler o histórico.");
        }

        Message saved = messageRepository.save(Message.builder()
                .conversation(conversation)
                .senderRole(side)
                .body(body.trim())
                .createdAt(LocalDateTime.now())
                .build());

        conversation.markReadBy(side, saved.getId());
        conversationRepository.save(conversation);
        return toResponse(saved);
    }

    @Transactional
    public void markRead(Long conversationId, String email) {
        Conversation conversation = findConversation(conversationId);
        MessageSender side = sideOf(conversation.getTrainerStudent(), email);

        messageRepository.findFirstByConversationIdOrderByIdDesc(conversationId).ifPresent(latest -> {
            Long current = conversation.lastReadBy(side);
            if (current == null || current < latest.getId()) {
                conversation.markReadBy(side, latest.getId());
                conversationRepository.save(conversation);
            }
        });
    }
}
