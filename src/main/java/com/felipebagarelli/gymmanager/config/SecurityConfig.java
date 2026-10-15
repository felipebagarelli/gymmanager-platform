package com.felipebagarelli.gymmanager.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter authoritiesConverter = new JwtGrantedAuthoritiesConverter();
        authoritiesConverter.setAuthorityPrefix("ROLE_");
        authoritiesConverter.setAuthoritiesClaimName("role");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
        return converter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http,
                                                     JwtAuthenticationConverter jwtAuthenticationConverter) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // pré-flight de CORS não carrega Authorization; sem isso o navegador
                        // recebe 401/403 no OPTIONS e a chamada real nunca sai.
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/actuator/health", "/actuator/health/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/v1/auth/login", "/api/v1/auth/register-trainer").permitAll()
                        .requestMatchers("/api/v1/trainers/*/students").hasRole("TRAINER")
                        .requestMatchers(HttpMethod.PUT, "/api/v1/students/*").hasRole("TRAINER")
                        .requestMatchers(HttpMethod.DELETE, "/api/v1/students/*").hasRole("TRAINER")
                        .requestMatchers(HttpMethod.POST, "/workouts", "/workouts/*/assignments", "/workouts/*/duplicate", "/workout-exercises", "/exercises").hasRole("TRAINER")
                        .requestMatchers(HttpMethod.GET, "/workouts/*/assignments").hasRole("TRAINER")
                        .requestMatchers(HttpMethod.PUT, "/workouts/*", "/workout-exercises/*", "/workout-exercises/workout/*/order", "/exercises/*").hasRole("TRAINER")
                        .requestMatchers(HttpMethod.DELETE, "/workouts/*", "/workouts/*/assignments/*", "/workout-exercises/*", "/exercises/*").hasRole("TRAINER")
                        .requestMatchers(HttpMethod.POST, "/api/v1/workout-sessions/**").hasRole("STUDENT")
                        .requestMatchers(HttpMethod.PUT, "/api/v1/workout-sessions/**").hasRole("STUDENT")
                        .requestMatchers(HttpMethod.DELETE, "/api/v1/workout-sessions/**").hasRole("STUDENT")
                        .requestMatchers("/api/v1/ai/**").hasRole("STUDENT")
                        .requestMatchers(HttpMethod.POST, "/api/v1/billing/webhook").permitAll()
                        .requestMatchers("/api/v1/plans/available", "/api/v1/subscriptions/**").hasRole("STUDENT")
                        .requestMatchers("/api/v1/plans", "/api/v1/plans/*", "/api/v1/billing/payout-account/**", "/api/v1/billing/subscriptions").hasRole("TRAINER")
                        .anyRequest().authenticated()
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter))
                );

        return http.build();
    }
}
