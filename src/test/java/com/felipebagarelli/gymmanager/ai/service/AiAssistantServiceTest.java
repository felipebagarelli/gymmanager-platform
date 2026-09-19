package com.felipebagarelli.gymmanager.ai.service;

import com.felipebagarelli.gymmanager.ai.dto.AiExchangeResponse;
import com.felipebagarelli.gymmanager.ai.entity.AiMessage;
import com.felipebagarelli.gymmanager.ai.entity.AiRole;
import com.felipebagarelli.gymmanager.ai.provider.AiProvider;
import com.felipebagarelli.gymmanager.ai.provider.AiProviderException;
import com.felipebagarelli.gymmanager.ai.provider.AiReply;
import com.felipebagarelli.gymmanager.ai.provider.AiRequest;
import com.felipebagarelli.gymmanager.ai.provider.AiUnavailableException;
import com.felipebagarelli.gymmanager.ai.repository.AiMessageRepository;
import com.felipebagarelli.gymmanager.exception.RateLimitExceededException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AiAssistantServiceTest {

    private static final String EMAIL = "aluno@example.com";

    @Mock
    private AiProvider provider;
    @Mock
    private AiContextBuilder contextBuilder;
    @Mock
    private AiMessageRepository messageRepository;
    @Mock
    private StudentProfileRepository studentRepository;

    private AiAssistantService service;
    private StudentProfile student;

    @BeforeEach
    void setUp() {
        service = new AiAssistantService(provider, contextBuilder, messageRepository, studentRepository, 3, 4);
        student = StudentProfile.builder().id(7L).name("Ana").active(true).build();
        when(studentRepository.findByUserEmail(EMAIL)).thenReturn(Optional.of(student));
        when(contextBuilder.build(student)).thenReturn("SYS");
        when(messageRepository.findByStudentIdOrderByIdDesc(eq(7L), any(Pageable.class))).thenReturn(List.of());
    }

    private AiMessage msg(AiRole role, String body) {
        return AiMessage.builder().student(student).role(role).body(body).createdAt(LocalDateTime.now()).build();
    }

    private void used(long count) {
        when(messageRepository.countByStudentIdAndRoleAndCreatedAtGreaterThanEqual(eq(7L), eq(AiRole.USER), any()))
                .thenReturn(count);
    }

    @Test
    void ask_persistsBothMessagesAndReturnsRemaining() {
        used(1);
        when(provider.ask(any())).thenReturn(new AiReply("Resposta", 10, 5));

        AiExchangeResponse out = service.ask(EMAIL, "  Como faço agachamento?  ");

        assertThat(out.answer().body()).isEqualTo("Resposta");
        assertThat(out.question().body()).isEqualTo("Como faço agachamento?");
        assertThat(out.remainingToday()).isEqualTo(1);
        verify(messageRepository).saveAll(any());
    }

    @Test
    void ask_overDailyLimit_throwsAndDoesNotCallProvider() {
        used(3);

        assertThatThrownBy(() -> service.ask(EMAIL, "oi")).isInstanceOf(RateLimitExceededException.class);
        verify(provider, never()).ask(any());
        verify(messageRepository, never()).saveAll(any());
    }

    @Test
    void ask_providerFails_persistsNothing() {
        used(0);
        when(provider.ask(any())).thenThrow(new AiProviderException("falhou"));

        assertThatThrownBy(() -> service.ask(EMAIL, "oi")).isInstanceOf(AiProviderException.class);
        verify(messageRepository, never()).saveAll(any());
    }

    @Test
    void ask_providerUnavailable_propagates() {
        used(0);
        when(provider.ask(any())).thenThrow(new AiUnavailableException("off"));

        assertThatThrownBy(() -> service.ask(EMAIL, "oi")).isInstanceOf(AiUnavailableException.class);
    }

    @Test
    void ask_historyIsChronologicalAndStartsWithUserTurn() {
        used(0);
        when(messageRepository.findByStudentIdOrderByIdDesc(eq(7L), any(Pageable.class)))
                .thenReturn(List.of(msg(AiRole.ASSISTANT, "r2"), msg(AiRole.USER, "p2"), msg(AiRole.ASSISTANT, "r1")));
        when(provider.ask(any())).thenReturn(new AiReply("ok", 1, 1));

        service.ask(EMAIL, "nova");

        ArgumentCaptor<AiRequest> captor = ArgumentCaptor.forClass(AiRequest.class);
        verify(provider).ask(captor.capture());
        assertThat(captor.getValue().history()).extracting(t -> t.text()).containsExactly("p2", "r2");
        assertThat(captor.getValue().question()).isEqualTo("nova");
        assertThat(captor.getValue().systemPrompt()).isEqualTo("SYS");
    }

    @Test
    void usage_reportsRemaining() {
        used(2);
        assertThat(service.usage(EMAIL).remainingToday()).isEqualTo(1);
    }

    @Test
    void ask_unknownStudent_throwsNotFound() {
        when(studentRepository.findByUserEmail("x@x.com")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.ask("x@x.com", "oi")).isInstanceOf(ResourceNotFoundException.class);
    }
}
