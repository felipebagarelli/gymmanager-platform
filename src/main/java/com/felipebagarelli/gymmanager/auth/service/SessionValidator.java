package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;

import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

/**
 * Token so vale para conta ativa e se foi emitido depois da ultima troca de senha: trocar a senha
 * (ou excluir a conta) encerra as sessoes abertas em outros aparelhos.
 */
public class SessionValidator implements OAuth2TokenValidator<Jwt> {

    private static final OAuth2Error INVALID = new OAuth2Error("invalid_token", "Sessão encerrada. Entre de novo.", null);

    private final UserRepository userRepository;

    public SessionValidator(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        Optional<User> user = userRepository.findByEmailIgnoreCase(token.getSubject() == null ? "" : token.getSubject());
        if (user.isEmpty() || !user.get().isActive()) {
            return OAuth2TokenValidatorResult.failure(INVALID);
        }
        if (user.get().getPasswordChangedAt() != null && token.getIssuedAt() != null) {
            Instant changed = user.get().getPasswordChangedAt().atZone(ZoneId.systemDefault()).toInstant().truncatedTo(ChronoUnit.SECONDS);
            if (token.getIssuedAt().isBefore(changed)) {
                return OAuth2TokenValidatorResult.failure(INVALID);
            }
        }
        return OAuth2TokenValidatorResult.success();
    }
}
