package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.exception.RateLimitExceededException;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Freia cadastro em massa e abuso das rotas publicas: no maximo N pedidos por hora por IP e por tipo
 * (cadastro, "esqueci a senha"...). Em memoria (uma instancia); com varias, trocar por armazenamento
 * compartilhado.
 */
@Component
public class IpRateLimiter {

    static final Duration WINDOW = Duration.ofHours(1);

    private final Map<String, Deque<Instant>> hits = new ConcurrentHashMap<>();
    private final Clock clock;

    public IpRateLimiter() {
        this(Clock.systemUTC());
    }

    IpRateLimiter(Clock clock) {
        this.clock = clock;
    }

    /** Conta o pedido; 429 se o IP ja fez {@code max} pedidos deste tipo na ultima hora. */
    public void check(String kind, String ip, int max) {
        String key = kind + "|" + (ip == null ? "" : ip);
        Deque<Instant> attempts = hits.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (attempts) {
            Instant limit = clock.instant().minus(WINDOW);
            while (!attempts.isEmpty() && attempts.peekFirst().isBefore(limit)) {
                attempts.pollFirst();
            }
            if (attempts.size() >= max) {
                throw new RateLimitExceededException("Muitas tentativas deste aparelho. Tente de novo mais tarde.");
            }
            attempts.addLast(clock.instant());
        }
    }
}
