package com.felipebagarelli.gymmanager.auth.service;

import com.felipebagarelli.gymmanager.auth.dto.request.LoginRequest;
import com.felipebagarelli.gymmanager.auth.dto.response.LoginResponse;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.AccountPendingException;
import com.felipebagarelli.gymmanager.exception.InvalidCredentialsException;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
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
    private final StudentProfileRepository studentProfileRepository;

    public AuthenticationService(AuthenticationManager authenticationManager,
                                  UserRepository userRepository,
                                  JwtService jwtService,
                                  LoginAttemptLimiter loginAttemptLimiter,
                                  StudentProfileRepository studentProfileRepository) {
        this.loginAttemptLimiter = loginAttemptLimiter;
        this.studentProfileRepository = studentProfileRepository;
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
        // senha certa, mas a conta ainda nao foi liberada: o app mostra o passo que falta
        if (user.getEmailVerifiedAt() == null) {
            throw new AccountPendingException(AccountPendingException.EMAIL_NOT_VERIFIED,
                    "Confirme seu e-mail para entrar. Enviamos um código para " + user.getEmail() + ".");
        }
        studentProfileRepository.findByUserEmail(user.getEmail())
                .filter(s -> s.getGuardianEmail() != null && s.getGuardianConsentAt() == null)
                .ifPresent(s -> {
                    throw new AccountPendingException(AccountPendingException.GUARDIAN_CONSENT_PENDING,
                            "Falta a autorização do seu responsável. Enviamos um pedido para o e-mail dele.");
                });
        String token = jwtService.generateToken(user);

        return new LoginResponse(token, jwtService.expirationSeconds(), user.getRole().name());
    }
}
