package com.felipebagarelli.gymmanager.config;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;

import java.time.Instant;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class SecurityConfigTest {

    @Test
    void jwtAuthenticationConverter_mapsRoleClaimToRoleAuthority() {
        SecurityConfig securityConfig = new SecurityConfig();

        Jwt jwt = Jwt.withTokenValue("token-value")
                .header("alg", "HS256")
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(3600))
                .subject("trainer@example.com")
                .claim("role", "TRAINER")
                .claims(claims -> claims.putAll(Map.of("userId", 1L)))
                .build();

        Authentication authentication = securityConfig.jwtAuthenticationConverter().convert(jwt);

        assertThat(authentication.getAuthorities())
                .extracting(Object::toString)
                .contains("ROLE_TRAINER");
    }
}
