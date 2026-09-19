package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

class JwtServiceTest {

    private JwtService jwtService;
    private JwtDecoder jwtDecoder;

    @BeforeEach
    void setUp() {
        SecretKey secretKey = new SecretKeySpec(
                "a-very-long-test-secret-used-only-for-unit-tests-1234567890".getBytes(StandardCharsets.UTF_8),
                "HmacSHA256");

        JwtEncoder jwtEncoder = NimbusJwtEncoder.withSecretKey(secretKey)
                .algorithm(MacAlgorithm.HS256)
                .build();

        jwtDecoder = NimbusJwtDecoder.withSecretKey(secretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();

        jwtService = new JwtService(jwtEncoder);
    }

    @Test
    void generateToken_producesTokenDecodableWithSameClaims() {
        User user = User.builder()
                .id(42L)
                .email("trainer@example.com")
                .role(Role.TRAINER)
                .active(true)
                .build();

        String token = jwtService.generateToken(user);
        Jwt decoded = jwtDecoder.decode(token);

        Long userId = decoded.getClaim("userId");

        assertThat(decoded.getSubject()).isEqualTo("trainer@example.com");
        assertThat(decoded.getClaimAsString("role")).isEqualTo("TRAINER");
        assertThat(userId).isEqualTo(42L);
        assertThat(decoded.getExpiresAt()).isAfter(decoded.getIssuedAt());
    }
}
