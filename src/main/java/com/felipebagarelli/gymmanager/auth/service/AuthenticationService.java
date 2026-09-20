package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.auth.dto.request.LoginRequest;
import com.felipebagarelli.gymmanager.auth.dto.response.LoginResponse;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.InvalidCredentialsException;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.stereotype.Service;

@Service
public class AuthenticationService {

    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final LoginAttemptLimiter loginAttemptLimiter;

    public AuthenticationService(AuthenticationManager authenticationManager,
                                  UserRepository userRepository,
                                  JwtService jwtService,
                                  LoginAttemptLimiter loginAttemptLimiter) {
        this.loginAttemptLimiter = loginAttemptLimiter;
        this.authenticationManager = authenticationManager;
        this.userRepository = userRepository;
        this.jwtService = jwtService;
    }

    public LoginResponse login(LoginRequest request) {
        loginAttemptLimiter.assertAllowed(request.email());
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.email(), request.password()));
        } catch (AuthenticationException ex) {
            loginAttemptLimiter.recordFailure(request.email());
            throw new InvalidCredentialsException("E-mail ou senha inválidos!");
        }

        User user = userRepository.findByEmail(request.email())
                .orElseThrow(() -> new InvalidCredentialsException("E-mail ou senha inválidos!"));

        loginAttemptLimiter.reset(request.email());
        String token = jwtService.generateToken(user);

        return new LoginResponse(token, jwtService.expirationSeconds(), user.getRole().name());
    }
}
