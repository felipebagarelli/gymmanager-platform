package com.felipebagarelli.gymmanager.trainer.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.EmailAlreadyInUseException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.trainer.dto.request.RegisterTrainerRequest;
import com.felipebagarelli.gymmanager.trainer.dto.response.TrainerProfileResponse;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TrainerServiceTest {

    @Mock
    private TrainerProfileRepository trainerProfileRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private TrainerService trainerService;

    @Test
    void registerTrainer_savesUserAndTrainerProfile_whenEmailNotInUse() {
        RegisterTrainerRequest request = new RegisterTrainerRequest(
                "trainer@example.com", "senhaSegura123", "João Personal", "11999999999");

        when(userRepository.existsByEmailIgnoreCase(request.email())).thenReturn(false);
        when(passwordEncoder.encode(request.password())).thenReturn("hashed-password");
        when(trainerProfileRepository.save(any(TrainerProfile.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TrainerProfileResponse response = trainerService.registerTrainer(request);

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        User savedUser = userCaptor.getValue();

        assertThat(savedUser.getEmail()).isEqualTo("trainer@example.com");
        assertThat(savedUser.getPasswordHash()).isEqualTo("hashed-password");
        assertThat(savedUser.getRole()).isEqualTo(Role.TRAINER);
        assertThat(savedUser.isActive()).isTrue();

        assertThat(response.email()).isEqualTo("trainer@example.com");
        assertThat(response.displayName()).isEqualTo("João Personal");
        assertThat(response.phone()).isEqualTo("11999999999");
    }

    @Test
    void registerTrainer_throwsEmailAlreadyInUseException_whenEmailExists() {
        RegisterTrainerRequest request = new RegisterTrainerRequest(
                "trainer@example.com", "senhaSegura123", "João Personal", "11999999999");

        when(userRepository.existsByEmailIgnoreCase(request.email())).thenReturn(true);

        assertThatThrownBy(() -> trainerService.registerTrainer(request))
                .isInstanceOf(EmailAlreadyInUseException.class);

        verify(userRepository, never()).save(any());
        verify(trainerProfileRepository, never()).save(any());
    }

    @Test
    void getTrainerById_returnsResponse_whenFound() {
        User user = User.builder().email("trainer@example.com").role(Role.TRAINER).build();
        TrainerProfile trainerProfile = TrainerProfile.builder()
                .id(1L)
                .user(user)
                .displayName("João Personal")
                .phone("11999999999")
                .build();

        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(trainerProfile));

        TrainerProfileResponse response = trainerService.getTrainerById(1L);

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.email()).isEqualTo("trainer@example.com");
    }

    @Test
    void getTrainerById_throwsResourceNotFoundException_whenNotFound() {
        when(trainerProfileRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> trainerService.getTrainerById(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
