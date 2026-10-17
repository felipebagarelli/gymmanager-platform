package com.felipebagarelli.gymmanager.account.service;

import com.felipebagarelli.gymmanager.account.entity.AccountToken;
import com.felipebagarelli.gymmanager.account.entity.TokenPurpose;
import com.felipebagarelli.gymmanager.account.repository.AccountTokenRepository;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;

/**
 * Codigos de 6 digitos (confirmar e-mail, trocar senha) e links (autorizacao do responsavel).
 * Uso unico, com validade; o codigo trava depois de {@value #MAX_ATTEMPTS} tentativas erradas.
 * O banco guarda so o hash.
 */
@Component
public class AccountTokenService {

    static final int MAX_ATTEMPTS = 5;
    static final Duration CODE_TTL = Duration.ofMinutes(30);
    static final Duration LINK_TTL = Duration.ofDays(7);
    static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);

    private final AccountTokenRepository repository;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    @Autowired
    public AccountTokenService(AccountTokenRepository repository) {
        this(repository, Clock.systemDefaultZone());
    }

    AccountTokenService(AccountTokenRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }

    static String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String codeHash(User user, TokenPurpose purpose, String code) {
        return sha256(purpose.name() + ":" + user.getId() + ":" + code);
    }

    /** Ja enviou um codigo/link desse tipo ha menos de 1 minuto (evita spam de e-mail). */
    public boolean inCooldown(User user, TokenPurpose purpose) {
        return repository.findFirstByUserIdAndPurposeAndUsedAtIsNullOrderByCreatedAtDesc(user.getId(), purpose)
                .map(t -> t.getCreatedAt().plus(RESEND_COOLDOWN).isAfter(now()))
                .orElse(false);
    }

    /** Invalida os anteriores do mesmo tipo: so o ultimo enviado vale. */
    private void invalidate(User user, TokenPurpose purpose) {
        for (AccountToken old : repository.findByUserIdAndPurposeAndUsedAtIsNull(user.getId(), purpose)) {
            old.setUsedAt(now());
            repository.save(old);
        }
    }

    public String issueCode(User user, TokenPurpose purpose) {
        invalidate(user, purpose);
        String code = String.format("%06d", random.nextInt(1_000_000));
        repository.save(AccountToken.builder()
                .user(user)
                .purpose(purpose)
                .tokenHash(codeHash(user, purpose, code))
                .expiresAt(now().plus(CODE_TTL))
                .createdAt(now())
                .build());
        return code;
    }

    public String issueLink(User user, TokenPurpose purpose) {
        invalidate(user, purpose);
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        repository.save(AccountToken.builder()
                .user(user)
                .purpose(purpose)
                .tokenHash(sha256(token))
                .expiresAt(now().plus(LINK_TTL))
                .createdAt(now())
                .build());
        return token;
    }

    /**
     * Confere o codigo. Erro conta tentativa (quem chama precisa nao desfazer a transacao em
     * BadRequestException, senao a contagem se perde).
     */
    public void consumeCode(User user, TokenPurpose purpose, String code) {
        AccountToken token = repository
                .findFirstByUserIdAndPurposeAndUsedAtIsNullOrderByCreatedAtDesc(user.getId(), purpose)
                .filter(t -> t.getExpiresAt().isAfter(now()))
                .orElseThrow(() -> new BadRequestException("Código expirado ou inválido. Peça um novo."));
        if (token.getAttempts() >= MAX_ATTEMPTS) {
            throw new BadRequestException("Muitas tentativas. Peça um novo código.");
        }
        if (!MessageDigest.isEqual(token.getTokenHash().getBytes(StandardCharsets.UTF_8),
                codeHash(user, purpose, code == null ? "" : code.trim()).getBytes(StandardCharsets.UTF_8))) {
            token.setAttempts(token.getAttempts() + 1);
            repository.save(token);
            throw new BadRequestException("Código incorreto.");
        }
        token.setUsedAt(now());
        repository.save(token);
    }

    /** Link ainda valido (sem consumir), para mostrar a pagina de autorizacao. */
    public Optional<AccountToken> peekLink(String token, TokenPurpose purpose) {
        if (token == null || token.isBlank()) return Optional.empty();
        return repository.findByTokenHashAndPurpose(sha256(token), purpose)
                .filter(t -> t.getUsedAt() == null && t.getExpiresAt().isAfter(now()));
    }

    public AccountToken consumeLink(String token, TokenPurpose purpose) {
        AccountToken found = peekLink(token, purpose)
                .orElseThrow(() -> new BadRequestException("Este link expirou ou já foi usado."));
        found.setUsedAt(now());
        return repository.save(found);
    }
}
