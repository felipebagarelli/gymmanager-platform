package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.exception.RateLimitExceededException;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Freia tentativa de adivinhar senha: apos {@value #MAX_FAILURES} falhas em 15 minutos para o mesmo
 * e-mail, novas tentativas recebem 429 ate a janela esvaziar. Em memoria (uma instancia); com varias
 * instancias trocar por um armazenamento compartilhado.
 */
@Component
public class LoginAttemptLimiter {

    static final int MAX_FAILURES = 5;
    static final Duration WINDOW = Duration.ofMinutes(15);

    private final Map<String, Deque<Instant>> failures = new ConcurrentHashMap<>();
    private final Clock clock;

    public LoginAttemptLimiter() {
        this(Clock.systemUTC());
    }

    LoginAttemptLimiter(Clock clock) {
        this.clock = clock;
    }

    private static String key(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private void prune(Deque<Instant> attempts) {
        Instant limit = clock.instant().minus(WINDOW);
        while (!attempts.isEmpty() && attempts.peekFirst().isBefore(limit)) {
            attempts.pollFirst();
        }
    }

    /** Lanca 429 se o e-mail ja estourou o limite. */
    public void assertAllowed(String email) {
        Deque<Instant> attempts = failures.get(key(email));
        if (attempts == null) return;
        synchronized (attempts) {
            prune(attempts);
            if (attempts.size() >= MAX_FAILURES) {
                throw new RateLimitExceededException("Muitas tentativas de login. Tente novamente em alguns minutos.");
            }
        }
    }

    public void recordFailure(String email) {
        Deque<Instant> attempts = failures.computeIfAbsent(key(email), k -> new ArrayDeque<>());
        synchronized (attempts) {
            prune(attempts);
            attempts.addLast(clock.instant());
        }
    }

    public void reset(String email) {
        failures.remove(key(email));
    }
}
