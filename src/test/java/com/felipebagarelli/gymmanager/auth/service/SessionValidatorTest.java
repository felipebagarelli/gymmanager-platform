package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class SessionValidatorTest {

    private final UserRepository users = mock(UserRepository.class);
    private final SessionValidator validator = new SessionValidator(users);

    private static Jwt token(String subject, Instant issuedAt) {
        return Jwt.withTokenValue("t").header("alg", "HS256").subject(subject).issuedAt(issuedAt)
                .expiresAt(issuedAt.plusSeconds(3600)).build();
    }

    @Test
    void activeUser_isValid() {
        when(users.findByEmailIgnoreCase("ana@example.com")).thenReturn(Optional.of(User.builder().email("ana@example.com").active(true).build()));
        assertThat(validator.validate(token("ana@example.com", Instant.now())).hasErrors()).isFalse();
    }

    @Test
    void missingOrInactiveUser_isRejected() {
        when(users.findByEmailIgnoreCase("ana@example.com")).thenReturn(Optional.of(User.builder().email("ana@example.com").active(false).build()));
        assertThat(validator.validate(token("ana@example.com", Instant.now())).hasErrors()).isTrue();
        assertThat(validator.validate(token("ninguem@example.com", Instant.now())).hasErrors()).isTrue();
    }

    @Test
    void tokenIssuedBeforePasswordChange_isRejected_afterIsValid() {
        LocalDateTime changed = LocalDateTime.now().minusMinutes(10);
        when(users.findByEmailIgnoreCase("ana@example.com"))
                .thenReturn(Optional.of(User.builder().email("ana@example.com").active(true).passwordChangedAt(changed).build()));
        Instant changedAt = changed.atZone(java.time.ZoneId.systemDefault()).toInstant();
        assertThat(validator.validate(token("ana@example.com", changedAt.minusSeconds(60))).hasErrors()).isTrue();
        assertThat(validator.validate(token("ana@example.com", changedAt.plusSeconds(1))).hasErrors()).isFalse();
    }
}
