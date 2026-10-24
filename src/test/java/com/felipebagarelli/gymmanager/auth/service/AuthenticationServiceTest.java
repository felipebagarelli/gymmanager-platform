package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.auth.dto.request.LoginRequest;
import com.felipebagarelli.gymmanager.auth.dto.response.LoginResponse;
import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.AccountPendingException;
import com.felipebagarelli.gymmanager.exception.InvalidCredentialsException;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthenticationServiceTest {

    @Mock
    private AuthenticationManager authenticationManager;

    @Mock
    private UserRepository userRepository;

    @Mock
    private JwtService jwtService;

    @Mock
    private LoginAttemptLimiter loginAttemptLimiter;

    @Mock
    private StudentProfileRepository studentProfileRepository;

    @InjectMocks
    private AuthenticationService authenticationService;

    @Test
    void login_returnsTokenAndRole_whenCredentialsAreValid() {
        LoginRequest request = new LoginRequest("trainer@example.com", "senhaSegura123");
        User user = User.builder()
                .id(1L)
                .email("trainer@example.com")
                .role(Role.TRAINER)
                .active(true)
                .emailVerifiedAt(LocalDateTime.now())
                .build();

        when(userRepository.findByEmailIgnoreCase("trainer@example.com")).thenReturn(Optional.of(user));
        when(jwtService.generateToken(user)).thenReturn("fake-jwt-token");
        when(jwtService.expirationSeconds()).thenReturn(3600L);

        LoginResponse response = authenticationService.login(request);

        assertThat(response.token()).isEqualTo("fake-jwt-token");
        assertThat(response.role()).isEqualTo("TRAINER");
        assertThat(response.expiresInSeconds()).isEqualTo(3600L);
    }

    @Test
    void login_throwsInvalidCredentialsException_whenPasswordIsWrong() {
        LoginRequest request = new LoginRequest("trainer@example.com", "senhaErrada");

        when(authenticationManager.authenticate(any()))
                .thenThrow(new BadCredentialsException("Bad credentials"));

        assertThatThrownBy(() -> authenticationService.login(request))
                .isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    void login_throwsInvalidCredentialsException_whenUserDoesNotExist() {
        LoginRequest request = new LoginRequest("desconhecido@example.com", "senhaSegura123");

        when(authenticationManager.authenticate(any()))
                .thenThrow(new BadCredentialsException("Bad credentials"));

        assertThatThrownBy(() -> authenticationService.login(request))
                .isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    void login_blocksUntilTheEmailIsVerified() {
        User user = User.builder().id(2L).email("aluno@example.com").role(Role.STUDENT).active(true).build();
        when(userRepository.findByEmailIgnoreCase("aluno@example.com")).thenReturn(Optional.of(user));

        assertThatThrownBy(() -> authenticationService.login(new LoginRequest("aluno@example.com", "senhaSegura123")))
                .isInstanceOf(AccountPendingException.class)
                .extracting(e -> ((AccountPendingException) e).code())
                .isEqualTo(AccountPendingException.EMAIL_NOT_VERIFIED);
    }

    @Test
    void login_blocksTeenUntilTheGuardianApproves() {
        User user = User.builder().id(2L).email("teen@example.com").role(Role.STUDENT).active(true)
                .emailVerifiedAt(LocalDateTime.now()).build();
        when(userRepository.findByEmailIgnoreCase("teen@example.com")).thenReturn(Optional.of(user));
        StudentProfile teen = StudentProfile.builder().user(user).guardianName("Ana").guardianEmail("mae@example.com").build();
        when(studentProfileRepository.findByUserEmail("teen@example.com")).thenReturn(Optional.of(teen));

        assertThatThrownBy(() -> authenticationService.login(new LoginRequest("teen@example.com", "senhaSegura123")))
                .isInstanceOf(AccountPendingException.class)
                .extracting(e -> ((AccountPendingException) e).code())
                .isEqualTo(AccountPendingException.GUARDIAN_CONSENT_PENDING);

        teen.setGuardianConsentAt(LocalDateTime.now());
        when(jwtService.generateToken(user)).thenReturn("jwt");
        assertThat(authenticationService.login(new LoginRequest("teen@example.com", "senhaSegura123")).token()).isEqualTo("jwt");
    }
}
