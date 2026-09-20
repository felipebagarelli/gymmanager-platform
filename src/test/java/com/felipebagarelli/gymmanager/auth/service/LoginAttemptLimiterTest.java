package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.exception.RateLimitExceededException;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class LoginAttemptLimiterTest {

    private final AtomicReference<Instant> now = new AtomicReference<>(Instant.parse("2026-09-20T12:00:00Z"));
    private final Clock clock = new Clock() {
        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now.get();
        }
    };
    private final LoginAttemptLimiter limiter = new LoginAttemptLimiter(clock);

    private void fail(int times) {
        for (int i = 0; i < times; i++) limiter.recordFailure("Ana@Example.com");
    }

    @Test
    void blocksAfterMaxFailures_caseInsensitive() {
        fail(LoginAttemptLimiter.MAX_FAILURES - 1);
        assertThatCode(() -> limiter.assertAllowed("ana@example.com")).doesNotThrowAnyException();

        fail(1);
        assertThatThrownBy(() -> limiter.assertAllowed("ana@example.com")).isInstanceOf(RateLimitExceededException.class);
    }

    @Test
    void otherEmailsAreNotAffected() {
        fail(LoginAttemptLimiter.MAX_FAILURES);
        assertThatCode(() -> limiter.assertAllowed("outra@example.com")).doesNotThrowAnyException();
    }

    @Test
    void windowExpiresAndSuccessResets() {
        fail(LoginAttemptLimiter.MAX_FAILURES);
        now.set(now.get().plus(LoginAttemptLimiter.WINDOW).plusSeconds(1));
        assertThatCode(() -> limiter.assertAllowed("ana@example.com")).doesNotThrowAnyException();

        fail(LoginAttemptLimiter.MAX_FAILURES);
        limiter.reset("ana@example.com");
        assertThatCode(() -> limiter.assertAllowed("ana@example.com")).doesNotThrowAnyException();
    }
}
