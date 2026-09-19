package com.felipebagarelli.gymmanager.ai.service;

import com.felipebagarelli.gymmanager.ai.dto.AiExchangeResponse;
import com.felipebagarelli.gymmanager.ai.dto.AiMessageResponse;
import com.felipebagarelli.gymmanager.ai.dto.AiUsageResponse;
import com.felipebagarelli.gymmanager.ai.entity.AiMessage;
import com.felipebagarelli.gymmanager.ai.entity.AiRole;
import com.felipebagarelli.gymmanager.ai.provider.AiProvider;
import com.felipebagarelli.gymmanager.ai.provider.AiReply;
import com.felipebagarelli.gymmanager.ai.provider.AiRequest;
import com.felipebagarelli.gymmanager.ai.provider.AiTurn;
import com.felipebagarelli.gymmanager.ai.repository.AiMessageRepository;
import com.felipebagarelli.gymmanager.exception.RateLimitExceededException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Assistente somente leitura: responde e sugere, nunca altera dados de negocio.
 * A conversa e privada do aluno autenticado (nao ha id na URL).
 */
@Service
public class AiAssistantService {

    private final AiProvider aiProvider;
    private final AiContextBuilder contextBuilder;
    private final AiMessageRepository messageRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final long dailyLimit;
    private final int historyMessages;

    public AiAssistantService(AiProvider aiProvider,
                              AiContextBuilder contextBuilder,
                              AiMessageRepository messageRepository,
                              StudentProfileRepository studentProfileRepository,
                              @Value("${app.ai.daily-limit}") long dailyLimit,
                              @Value("${app.ai.history-messages}") int historyMessages) {
        this.aiProvider = aiProvider;
        this.contextBuilder = contextBuilder;
        this.messageRepository = messageRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.dailyLimit = dailyLimit;
        this.historyMessages = historyMessages;
    }

    private AiMessageResponse toResponse(AiMessage message) {
        return new AiMessageResponse(message.getId(), message.getRole(), message.getBody(), message.getCreatedAt());
    }

    private StudentProfile findStudent(String email) {
        return studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
    }

    private long usedToday(Long studentId) {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        return messageRepository.countByStudentIdAndRoleAndCreatedAtGreaterThanEqual(studentId, AiRole.USER, startOfDay);
    }

    /** Ultimas falas em ordem cronologica, sempre comecando por uma fala do aluno. */
    private List<AiMessage> recent(Long studentId, int size) {
        List<AiMessage> latest = new ArrayList<>(
                messageRepository.findByStudentIdOrderByIdDesc(studentId, PageRequest.of(0, size)));
        Collections.reverse(latest);
        while (!latest.isEmpty() && latest.get(0).getRole() != AiRole.USER) {
            latest.remove(0);
        }
        return latest;
    }

    public List<AiMessageResponse> history(String email, int limit) {
        StudentProfile student = findStudent(email);
        return recent(student.getId(), Math.max(1, Math.min(limit, 100))).stream().map(this::toResponse).toList();
    }

    public AiUsageResponse usage(String email) {
        long used = usedToday(findStudent(email).getId());
        return new AiUsageResponse(dailyLimit, used, Math.max(0, dailyLimit - used));
    }

    public AiExchangeResponse ask(String email, String question) {
        StudentProfile student = findStudent(email);

        long used = usedToday(student.getId());
        if (used >= dailyLimit) {
            throw new RateLimitExceededException(
                    "Você atingiu o limite de " + dailyLimit + " perguntas por dia. Volte amanhã!");
        }

        String cleanQuestion = question.trim();
        List<AiTurn> history = recent(student.getId(), historyMessages).stream()
                .map(message -> new AiTurn(message.getRole(), message.getBody()))
                .toList();

        // chamada externa fora de qualquer transacao; se falhar, nada e gravado nem contado
        AiReply reply = aiProvider.ask(new AiRequest(contextBuilder.build(student), history, cleanQuestion));

        LocalDateTime now = LocalDateTime.now();
        AiMessage asked = AiMessage.builder().student(student).role(AiRole.USER).body(cleanQuestion).createdAt(now).build();
        AiMessage answered = AiMessage.builder().student(student).role(AiRole.ASSISTANT)
                .body(truncate(reply.text())).createdAt(now).build();
        messageRepository.saveAll(List.of(asked, answered));

        return new AiExchangeResponse(toResponse(asked), toResponse(answered), Math.max(0, dailyLimit - used - 1));
    }

    private String truncate(String text) {
        return text.length() > 8000 ? text.substring(0, 7999) + "…" : text;
    }
}
