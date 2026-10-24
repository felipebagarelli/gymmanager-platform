package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.exception.RateLimitExceededException;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class IpRateLimiterTest {

    private final AtomicReference<Instant> now = new AtomicReference<>(Instant.parse("2026-10-24T12:00:00Z"));
    private final IpRateLimiter limiter = new IpRateLimiter(new Clock() {
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
    });

    @Test
    void blocksAfterTheLimit_perIpAndKind_andFreesAfterAnHour() {
        for (int i = 0; i < 5; i++) limiter.check("register", "1.1.1.1", 5);
        assertThatThrownBy(() -> limiter.check("register", "1.1.1.1", 5)).isInstanceOf(RateLimitExceededException.class);
        // outro IP e outro tipo de pedido nao sao afetados
        assertThatCode(() -> limiter.check("register", "2.2.2.2", 5)).doesNotThrowAnyException();
        assertThatCode(() -> limiter.check("email", "1.1.1.1", 5)).doesNotThrowAnyException();
        now.set(now.get().plusSeconds(3601));
        assertThatCode(() -> limiter.check("register", "1.1.1.1", 5)).doesNotThrowAnyException();
    }
}
