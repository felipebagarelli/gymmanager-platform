package com.felipebagarelli.gymmanager.account.service;

import com.felipebagarelli.gymmanager.account.repository.AccountTokenRepository;
import com.felipebagarelli.gymmanager.ai.repository.AiMessageRepository;
import com.felipebagarelli.gymmanager.aiworkout.repository.AiWorkoutProposalRepository;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.chat.repository.ConversationRepository;
import com.felipebagarelli.gymmanager.chat.repository.MessageRepository;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.onboarding.repository.HealthScreeningRepository;
import com.felipebagarelli.gymmanager.onboarding.repository.TrainingProfileRepository;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscription;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscriptionStatus;
import com.felipebagarelli.gymmanager.platformplan.repository.PlatformSubscriptionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.student.service.StudentLinkService;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AccountDeletionServiceTest {

    private static final String EMAIL = "maria@example.com";

    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final StudentProfileRepository students = mock(StudentProfileRepository.class);
    private final TrainerProfileRepository trainers = mock(TrainerProfileRepository.class);
    private final TrainerStudentRepository links = mock(TrainerStudentRepository.class);
    private final StudentLinkService linkService = mock(StudentLinkService.class);
    private final PlatformSubscriptionRepository platform = mock(PlatformSubscriptionRepository.class);
    private final PaymentProvider payments = mock(PaymentProvider.class);
    private final AiMessageRepository aiMessages = mock(AiMessageRepository.class);
    private final HealthScreeningRepository screenings = mock(HealthScreeningRepository.class);
    private final TrainingProfileRepository profiles = mock(TrainingProfileRepository.class);
    private final ConversationRepository conversations = mock(ConversationRepository.class);
    private final AccountTokenRepository tokens = mock(AccountTokenRepository.class);
    private final User user = User.builder().id(5L).email(EMAIL).passwordHash("hash").active(true).build();
    private AccountDeletionService service;

    @BeforeEach
    void setUp() {
        when(users.findByEmailIgnoreCase(EMAIL)).thenReturn(Optional.of(user));
        when(encoder.matches("certa", "hash")).thenReturn(true);
        when(encoder.encode(anyString())).thenReturn("aleatoria");
        service = new AccountDeletionService(users, encoder, students, trainers, links, linkService, platform, payments,
                mock(PlanRepository.class), aiMessages, mock(AiWorkoutProposalRepository.class), screenings, profiles,
                conversations, mock(MessageRepository.class), tokens);
    }

    @Test
    void wrongPassword_deletesNothing() {
        assertThatThrownBy(() -> service.deleteMyAccount(EMAIL, "errada")).isInstanceOf(BadRequestException.class);
        assertThat(user.getEmail()).isEqualTo(EMAIL);
        verify(tokens, never()).deleteByUserId(5L);
    }

    @Test
    void student_cancelsCharges_erasesHealthData_andAnonymizes() {
        StudentProfile student = StudentProfile.builder().id(2L).name("Maria").phone("11999").weight(70.0).active(true).build();
        when(students.findByUserEmail(EMAIL)).thenReturn(Optional.of(student));
        TrainerStudent link = TrainerStudent.builder().id(9L).student(student).status(TrainerStudentStatus.ACTIVE).build();
        when(links.findByStudentId(2L)).thenReturn(Optional.of(link));
        PlatformSubscription pro = PlatformSubscription.builder().id(3L).status(PlatformSubscriptionStatus.ACTIVE)
                .stripeSubscriptionId("sub_pro").build();
        when(platform.findFirstByStudentIdOrderByIdDesc(2L)).thenReturn(Optional.of(pro));

        service.deleteMyAccount(EMAIL, "certa");

        verify(linkService).end(link);
        verify(payments).cancelPlatformSubscription("sub_pro");
        assertThat(pro.getStatus()).isEqualTo(PlatformSubscriptionStatus.CANCELED);
        verify(aiMessages).deleteByStudentId(2L);
        verify(screenings).deleteByStudentId(2L);
        verify(profiles).deleteByStudentId(2L);
        verify(tokens).deleteByUserId(5L);
        assertThat(student.getName()).isEqualTo(AccountDeletionService.DELETED_NAME);
        assertThat(student.getPhone()).isNull();
        assertThat(student.getWeight()).isNull();
        assertThat(user.getEmail()).isEqualTo("excluida-5@conta-excluida.invalid");
        assertThat(user.isActive()).isFalse();
        assertThat(user.getPasswordChangedAt()).isNotNull();
    }

    @Test
    void trainerWithStudents_mustEndThemFirst() {
        TrainerProfile trainer = TrainerProfile.builder().id(1L).displayName("Joao").build();
        when(trainers.findByUserEmail(EMAIL)).thenReturn(Optional.of(trainer));
        when(links.findByTrainerId(1L)).thenReturn(List.of(TrainerStudent.builder().status(TrainerStudentStatus.ACTIVE).build()));
        assertThatThrownBy(() -> service.deleteMyAccount(EMAIL, "certa")).isInstanceOf(ConflictException.class);
        assertThat(user.isActive()).isTrue();
    }

    @Test
    void trainerWithoutStudents_isUnlistedAndAnonymized() {
        TrainerProfile trainer = TrainerProfile.builder().id(1L).displayName("Joao").bio("bio").listed(true).build();
        when(trainers.findByUserEmail(EMAIL)).thenReturn(Optional.of(trainer));
        when(links.findByTrainerId(1L)).thenReturn(List.of(TrainerStudent.builder().status(TrainerStudentStatus.CANCELED).build()));
        service.deleteMyAccount(EMAIL, "certa");
        assertThat(trainer.isListed()).isFalse();
        assertThat(trainer.getBio()).isNull();
        assertThat(trainer.getDisplayName()).isEqualTo(AccountDeletionService.DELETED_NAME);
        assertThat(user.isActive()).isFalse();
    }
}
