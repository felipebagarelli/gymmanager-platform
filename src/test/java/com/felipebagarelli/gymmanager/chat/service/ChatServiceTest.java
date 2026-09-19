package com.felipebagarelli.gymmanager.chat.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.chat.dto.ConversationSummary;
import com.felipebagarelli.gymmanager.chat.dto.MessageResponse;
import com.felipebagarelli.gymmanager.chat.entity.Conversation;
import com.felipebagarelli.gymmanager.chat.entity.Message;
import com.felipebagarelli.gymmanager.chat.entity.MessageSender;
import com.felipebagarelli.gymmanager.chat.repository.ConversationRepository;
import com.felipebagarelli.gymmanager.chat.repository.MessageRepository;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.AccessDeniedException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ChatServiceTest {

    private static final String TRAINER = "trainer@example.com";
    private static final String STUDENT = "aluno@example.com";
    private static final String STRANGER = "outro@example.com";

    @Mock
    private ConversationRepository conversationRepository;
    @Mock
    private MessageRepository messageRepository;
    @Mock
    private TrainerStudentRepository trainerStudentRepository;

    @InjectMocks
    private ChatService chatService;

    private TrainerStudent link;
    private StudentProfile student;
    private Conversation conversation;

    @BeforeEach
    void setUp() {
        User trainerUser = User.builder().email(TRAINER).role(Role.TRAINER).build();
        User studentUser = User.builder().email(STUDENT).role(Role.STUDENT).build();
        TrainerProfile trainer = TrainerProfile.builder().id(1L).user(trainerUser).displayName("João Personal").build();
        student = StudentProfile.builder().id(2L).user(studentUser).name("Maria Aluna").active(true).build();
        link = TrainerStudent.builder().id(3L).trainer(trainer).student(student)
                .status(TrainerStudentStatus.ACTIVE).build();
        conversation = Conversation.builder().id(7L).trainerStudent(link).build();

        lenient().when(conversationRepository.findById(7L)).thenReturn(Optional.of(conversation));
        lenient().when(conversationRepository.save(any(Conversation.class))).thenAnswer(i -> i.getArgument(0));
        lenient().when(messageRepository.save(any(Message.class))).thenAnswer(i -> {
            Message m = i.getArgument(0);
            m.setId(100L);
            return m;
        });
    }

    private Message message(long id, MessageSender sender, String body) {
        return Message.builder().id(id).conversation(conversation).senderRole(sender).body(body)
                .createdAt(LocalDateTime.of(2026, 9, 19, 10, 0).plusMinutes(id)).build();
    }

    // ---- envio ----

    @Test
    void send_byTrainer_savesTrimmedMessageWithTrainerRoleAndMarksItReadForTheSender() {
        MessageResponse response = chatService.send(7L, "  Bom treino!  ", TRAINER);

        assertThat(response.senderRole()).isEqualTo(MessageSender.TRAINER);
        assertThat(response.body()).isEqualTo("Bom treino!");
        assertThat(conversation.getTrainerLastReadId()).isEqualTo(100L);
        assertThat(conversation.getStudentLastReadId()).isNull();
    }

    @Test
    void send_byStudent_usesStudentRole() {
        assertThat(chatService.send(7L, "Oi", STUDENT).senderRole()).isEqualTo(MessageSender.STUDENT);
        assertThat(conversation.getStudentLastReadId()).isEqualTo(100L);
    }

    @Test
    void send_byNonParticipant_isDenied() {
        assertThatThrownBy(() -> chatService.send(7L, "Oi", STRANGER)).isInstanceOf(AccessDeniedException.class);
        verify(messageRepository, never()).save(any());
    }

    @Test
    void send_whenLinkIsPausedOrCanceled_conflicts() {
        for (TrainerStudentStatus status : List.of(TrainerStudentStatus.PAUSED, TrainerStudentStatus.CANCELED)) {
            link.setStatus(status);
            assertThatThrownBy(() -> chatService.send(7L, "Oi", TRAINER)).isInstanceOf(ConflictException.class);
        }
        verify(messageRepository, never()).save(any());
    }

    @Test
    void send_whenStudentIsDeactivated_conflicts() {
        student.setActive(false);

        assertThatThrownBy(() -> chatService.send(7L, "Oi", STUDENT)).isInstanceOf(ConflictException.class);
    }

    @Test
    void send_unknownConversation_isNotFound() {
        assertThatThrownBy(() -> chatService.send(99L, "Oi", TRAINER)).isInstanceOf(ResourceNotFoundException.class);
    }

    // ---- leitura de mensagens ----

    @Test
    void messages_withoutAfter_returnsLatestInChronologicalOrder() {
        when(messageRepository.findByConversationIdOrderByIdDesc(eq(7L), any(Pageable.class)))
                .thenReturn(List.of(message(3, MessageSender.STUDENT, "c"), message(2, MessageSender.TRAINER, "b"),
                        message(1, MessageSender.STUDENT, "a")));

        List<MessageResponse> result = chatService.messages(7L, null, null, STUDENT);

        assertThat(result).extracting(MessageResponse::body).containsExactly("a", "b", "c");
    }

    @Test
    void messages_withAfter_returnsOnlyNewerOnesUsingTheGivenCursor() {
        when(messageRepository.findByConversationIdAndIdGreaterThanOrderByIdAsc(eq(7L), eq(5L), any(Pageable.class)))
                .thenReturn(List.of(message(6, MessageSender.TRAINER, "novo")));

        List<MessageResponse> result = chatService.messages(7L, 5L, 10, TRAINER);

        assertThat(result).extracting(MessageResponse::id).containsExactly(6L);
    }

    @Test
    void messages_limitIsClampedToTheAllowedRange() {
        when(messageRepository.findByConversationIdOrderByIdDesc(eq(7L), any(Pageable.class))).thenReturn(List.of());
        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);

        chatService.messages(7L, null, 100000, TRAINER);
        chatService.messages(7L, null, -5, TRAINER);

        verify(messageRepository, times(2)).findByConversationIdOrderByIdDesc(eq(7L), captor.capture());
        assertThat(captor.getAllValues()).extracting(Pageable::getPageSize).containsExactly(ChatService.MAX_LIMIT, 1);
    }

    @Test
    void messages_byNonParticipant_isDenied() {
        assertThatThrownBy(() -> chatService.messages(7L, null, null, STRANGER))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void messages_canStillBeReadWhenTheConversationIsClosed() {
        link.setStatus(TrainerStudentStatus.CANCELED);
        when(messageRepository.findByConversationIdOrderByIdDesc(eq(7L), any(Pageable.class)))
                .thenReturn(List.of(message(1, MessageSender.TRAINER, "historico")));

        assertThat(chatService.messages(7L, null, null, STUDENT)).hasSize(1);
    }

    // ---- marcar como lida ----

    @Test
    void markRead_updatesOnlyTheCallersSide() {
        when(messageRepository.findFirstByConversationIdOrderByIdDesc(7L))
                .thenReturn(Optional.of(message(9, MessageSender.TRAINER, "x")));

        chatService.markRead(7L, STUDENT);

        assertThat(conversation.getStudentLastReadId()).isEqualTo(9L);
        assertThat(conversation.getTrainerLastReadId()).isNull();
    }

    @Test
    void markRead_neverMovesBackwards() {
        conversation.setStudentLastReadId(20L);
        when(messageRepository.findFirstByConversationIdOrderByIdDesc(7L))
                .thenReturn(Optional.of(message(9, MessageSender.TRAINER, "x")));

        chatService.markRead(7L, STUDENT);

        assertThat(conversation.getStudentLastReadId()).isEqualTo(20L);
    }

    @Test
    void markRead_withNoMessagesDoesNothing() {
        when(messageRepository.findFirstByConversationIdOrderByIdDesc(7L)).thenReturn(Optional.empty());

        chatService.markRead(7L, TRAINER);

        verify(conversationRepository, never()).save(any());
    }

    @Test
    void markRead_byNonParticipant_isDenied() {
        assertThatThrownBy(() -> chatService.markRead(7L, STRANGER)).isInstanceOf(AccessDeniedException.class);
    }

    // ---- lista de conversas ----

    @Test
    void myConversations_forTrainer_createsMissingConversationAndReportsUnreadFromTheOtherSide() {
        when(trainerStudentRepository.findByTrainerUserEmail(TRAINER)).thenReturn(List.of(link));
        when(trainerStudentRepository.findByStudentUserEmail(TRAINER)).thenReturn(List.of());
        when(conversationRepository.findByTrainerStudentId(3L)).thenReturn(Optional.empty());
        when(conversationRepository.save(any(Conversation.class))).thenAnswer(i -> {
            Conversation c = i.getArgument(0);
            c.setId(7L);
            return c;
        });
        when(messageRepository.findFirstByConversationIdOrderByIdDesc(7L))
                .thenReturn(Optional.of(message(5, MessageSender.STUDENT, "Oi, coach")));
        when(messageRepository.countByConversationIdAndIdGreaterThanAndSenderRoleNot(7L, 0L, MessageSender.TRAINER))
                .thenReturn(2L);

        List<ConversationSummary> result = chatService.myConversations(TRAINER);

        assertThat(result).hasSize(1);
        ConversationSummary summary = result.get(0);
        assertThat(summary.id()).isEqualTo(7L);
        assertThat(summary.studentName()).isEqualTo("Maria Aluna");
        assertThat(summary.trainerName()).isEqualTo("João Personal");
        assertThat(summary.lastMessage().body()).isEqualTo("Oi, coach");
        assertThat(summary.unreadCount()).isEqualTo(2L);
        assertThat(summary.canSend()).isTrue();
        verify(conversationRepository).save(any(Conversation.class));
    }

    @Test
    void myConversations_forStudent_usesTheLastReadCursorAndFlagsClosedConversations() {
        link.setStatus(TrainerStudentStatus.PAUSED);
        conversation.setStudentLastReadId(4L);
        when(trainerStudentRepository.findByTrainerUserEmail(STUDENT)).thenReturn(List.of());
        when(trainerStudentRepository.findByStudentUserEmail(STUDENT)).thenReturn(List.of(link));
        when(conversationRepository.findByTrainerStudentId(3L)).thenReturn(Optional.of(conversation));
        when(messageRepository.findFirstByConversationIdOrderByIdDesc(7L)).thenReturn(Optional.empty());
        when(messageRepository.countByConversationIdAndIdGreaterThanAndSenderRoleNot(anyLong(), eq(4L), eq(MessageSender.STUDENT)))
                .thenReturn(0L);

        ConversationSummary summary = chatService.myConversations(STUDENT).get(0);

        assertThat(summary.unreadCount()).isZero();
        assertThat(summary.canSend()).isFalse();
        assertThat(summary.lastMessage()).isNull();
        verify(conversationRepository, never()).save(any());
    }

    @Test
    void myConversations_areOrderedByMostRecentMessageFirst() {
        TrainerStudent otherLink = TrainerStudent.builder().id(4L).trainer(link.getTrainer())
                .student(StudentProfile.builder().id(8L).name("Pedro").active(true)
                        .user(User.builder().email("pedro@example.com").build()).build())
                .status(TrainerStudentStatus.ACTIVE).build();
        Conversation otherConversation = Conversation.builder().id(8L).trainerStudent(otherLink).build();

        when(trainerStudentRepository.findByTrainerUserEmail(TRAINER)).thenReturn(List.of(link, otherLink));
        when(trainerStudentRepository.findByStudentUserEmail(TRAINER)).thenReturn(List.of());
        when(conversationRepository.findByTrainerStudentId(3L)).thenReturn(Optional.of(conversation));
        when(conversationRepository.findByTrainerStudentId(4L)).thenReturn(Optional.of(otherConversation));
        when(messageRepository.findFirstByConversationIdOrderByIdDesc(7L))
                .thenReturn(Optional.of(message(1, MessageSender.STUDENT, "antiga")));
        Message newer = Message.builder().id(50L).conversation(otherConversation).senderRole(MessageSender.STUDENT)
                .body("recente").createdAt(LocalDateTime.of(2026, 9, 20, 9, 0)).build();
        when(messageRepository.findFirstByConversationIdOrderByIdDesc(8L)).thenReturn(Optional.of(newer));

        List<ConversationSummary> result = chatService.myConversations(TRAINER);

        assertThat(result).extracting(ConversationSummary::studentName).containsExactly("Pedro", "Maria Aluna");
    }
}
