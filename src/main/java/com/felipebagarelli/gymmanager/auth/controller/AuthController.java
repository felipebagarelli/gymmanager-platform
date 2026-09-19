package com.felipebagarelli.gymmanager.auth.controller;

import com.felipebagarelli.gymmanager.auth.dto.request.LoginRequest;
import com.felipebagarelli.gymmanager.auth.dto.response.LoginResponse;
import com.felipebagarelli.gymmanager.auth.service.AuthenticationService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@CrossOrigin(origins = "http://localhost:5173")
public class AuthController {

    private final AuthenticationService authenticationService;

    public AuthController(AuthenticationService authenticationService) {
        this.authenticationService = authenticationService;
    }

    @PostMapping("/api/v1/auth/login")
    public LoginResponse login(@RequestBody @Valid LoginRequest request) {
        return authenticationService.login(request);
    }
}
