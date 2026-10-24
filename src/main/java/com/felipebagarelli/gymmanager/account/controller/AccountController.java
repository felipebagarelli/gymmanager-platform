package com.felipebagarelli.gymmanager.account.controller;

import com.felipebagarelli.gymmanager.account.dto.AccountDtos.EmailRequest;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.LegalInfoResponse;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.MessageResponse;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.RegisterStudentRequest;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.RegisterStudentResponse;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.ResetPasswordRequest;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.VerifyEmailRequest;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.VerifyEmailResponse;
import com.felipebagarelli.gymmanager.account.service.AccountService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Cadastro aberto, confirmacao de e-mail e troca de senha (rotas publicas). */
@RestController
public class AccountController {

    private static final String SENT_IF_EXISTS = "Se houver uma conta com este e-mail, enviamos as instruções.";

    private final AccountService accountService;
    private final com.felipebagarelli.gymmanager.auth.service.IpRateLimiter ipLimiter;
    private final String termsUrl;
    private final String privacyUrl;

    public AccountController(AccountService accountService,
                             com.felipebagarelli.gymmanager.auth.service.IpRateLimiter ipLimiter,
                             @Value("${app.legal.terms-url:}") String termsUrl,
                             @Value("${app.legal.privacy-url:}") String privacyUrl) {
        this.accountService = accountService;
        this.ipLimiter = ipLimiter;
        this.termsUrl = termsUrl;
        this.privacyUrl = privacyUrl;
    }

    @GetMapping("/api/v1/legal")
    public LegalInfoResponse legal() {
        return new LegalInfoResponse(accountService.termsVersion(), blankToNull(termsUrl), blankToNull(privacyUrl),
                AccountService.MINIMUM_AGE, AccountService.ADULT_AGE);
    }

    @PostMapping("/api/v1/auth/register-student")
    @ResponseStatus(HttpStatus.CREATED)
    public RegisterStudentResponse register(@RequestBody @Valid RegisterStudentRequest request, HttpServletRequest http) {
        ipLimiter.check("register", http.getRemoteAddr(), 5);
        return accountService.registerStudent(request, http.getRemoteAddr(), http.getHeader("User-Agent"));
    }

    @PostMapping("/api/v1/auth/verify-email")
    public VerifyEmailResponse verifyEmail(@RequestBody @Valid VerifyEmailRequest request, HttpServletRequest http) {
        ipLimiter.check("code", http.getRemoteAddr(), 30);
        return accountService.verifyEmail(request.email(), request.code());
    }

    @PostMapping("/api/v1/auth/resend-verification")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse resendVerification(@RequestBody @Valid EmailRequest request, HttpServletRequest http) {
        ipLimiter.check("email", http.getRemoteAddr(), 10);
        accountService.resendVerification(request.email());
        return new MessageResponse(SENT_IF_EXISTS);
    }

    @PostMapping("/api/v1/auth/resend-guardian")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse resendGuardian(@RequestBody @Valid EmailRequest request, HttpServletRequest http) {
        ipLimiter.check("email", http.getRemoteAddr(), 10);
        accountService.resendGuardianRequest(request.email());
        return new MessageResponse("Se houver um pedido pendente, enviamos de novo ao responsável.");
    }

    @PostMapping("/api/v1/auth/forgot-password")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse forgotPassword(@RequestBody @Valid EmailRequest request, HttpServletRequest http) {
        ipLimiter.check("email", http.getRemoteAddr(), 10);
        accountService.forgotPassword(request.email());
        return new MessageResponse(SENT_IF_EXISTS);
    }

    @PostMapping("/api/v1/auth/reset-password")
    public MessageResponse resetPassword(@RequestBody @Valid ResetPasswordRequest request, HttpServletRequest http) {
        ipLimiter.check("code", http.getRemoteAddr(), 30);
        accountService.resetPassword(request.email(), request.code(), request.newPassword());
        return new MessageResponse("Senha alterada. Entre com a nova senha.");
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
