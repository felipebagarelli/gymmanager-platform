package com.felipebagarelli.gymmanager.ai.controller;

import com.felipebagarelli.gymmanager.ai.dto.AiUsageResponse;
import com.felipebagarelli.gymmanager.ai.service.AiAssistantService;
import com.felipebagarelli.gymmanager.auth.config.JwtConfig;
import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.service.JwtService;
import com.felipebagarelli.gymmanager.config.CorsConfig;
import com.felipebagarelli.gymmanager.config.SecurityConfig;
import com.felipebagarelli.gymmanager.exception.GlobalExceptionHandler;
import com.felipebagarelli.gymmanager.exception.RateLimitExceededException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AiController.class)
@Import({SecurityConfig.class, CorsConfig.class, JwtConfig.class, JwtService.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = {"jwt.secret=test-secret-used-only-in-ai-security-tests-1234567890", "app.cors.allowed-origins=http://localhost:5173"})
class AiSecurityTest {

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JwtService jwtService;
    @MockitoBean
    private AiAssistantService assistantService;

    private String tokenFor(Role role) {
        return jwtService.generateToken(User.builder().id(1L).email("u@example.com").role(role).active(true).build());
    }

    @Test
    void withoutToken_returns401() throws Exception {
        mockMvc.perform(get("/api/v1/ai/usage")).andExpect(status().isUnauthorized());
    }

    @Test
    void trainer_returns403() throws Exception {
        mockMvc.perform(get("/api/v1/ai/messages").header("Authorization", "Bearer " + tokenFor(Role.TRAINER)))
                .andExpect(status().isForbidden());
    }

    @Test
    void student_canReadUsage() throws Exception {
        when(assistantService.usage(anyString())).thenReturn(new AiUsageResponse(30, 1, 29));
        mockMvc.perform(get("/api/v1/ai/usage").header("Authorization", "Bearer " + tokenFor(Role.STUDENT)))
                .andExpect(status().isOk());
    }

    @Test
    void student_blankQuestion_returns400() throws Exception {
        mockMvc.perform(post("/api/v1/ai/messages").header("Authorization", "Bearer " + tokenFor(Role.STUDENT))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"question\":\"  \"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void student_overLimit_returns429() throws Exception {
        when(assistantService.ask(anyString(), any())).thenThrow(new RateLimitExceededException("limite"));
        mockMvc.perform(post("/api/v1/ai/messages").header("Authorization", "Bearer " + tokenFor(Role.STUDENT))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"question\":\"oi\"}"))
                .andExpect(status().isTooManyRequests());
    }
}
