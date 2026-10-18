package com.felipebagarelli.gymmanager.platformplan.controller;

import com.felipebagarelli.gymmanager.auth.config.JwtConfig;
import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.service.JwtService;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.config.CorsConfig;
import com.felipebagarelli.gymmanager.config.SecurityConfig;
import com.felipebagarelli.gymmanager.exception.GlobalExceptionHandler;
import com.felipebagarelli.gymmanager.platformplan.service.PlatformPlanService;
import com.felipebagarelli.gymmanager.platformplan.service.PlatformWebhookService;
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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = PlatformPlanController.class)
@Import({SecurityConfig.class, CorsConfig.class, JwtConfig.class, JwtService.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = {"jwt.secret=test-secret-used-only-in-platform-plan-tests-1234567890", "app.cors.allowed-origins=http://localhost:5173"})
class PlatformPlanSecurityTest {

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JwtService jwtService;
    @MockitoBean
    private PlatformPlanService planService;
    @MockitoBean
    private PlatformWebhookService webhookService;

    private String bearer(Role role) {
        return "Bearer " + jwtService.generateToken(User.builder().id(1L).email("u@example.com").role(role).active(true).build());
    }

    @Test
    void platformPlan_isStudentOnly() throws Exception {
        when(planService.subscribe(any(), anyString())).thenReturn(new UrlResponse("https://checkout"));
        mockMvc.perform(post("/api/v1/platform-plan/subscribe").header("Authorization", bearer(Role.STUDENT))
                .contentType(MediaType.APPLICATION_JSON).content("{\"interval\":\"MONTHLY\"}")).andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/platform-plan/subscribe").header("Authorization", bearer(Role.TRAINER))
                .contentType(MediaType.APPLICATION_JSON).content("{\"interval\":\"MONTHLY\"}")).andExpect(status().isForbidden());
        mockMvc.perform(get("/api/v1/platform-plan")).andExpect(status().isUnauthorized());
    }

    @Test
    void webhookAndReturnPage_arePublic() throws Exception {
        mockMvc.perform(post("/api/v1/billing/platform-webhook").content("{}")).andExpect(status().isOk());
        mockMvc.perform(get("/checkout/retorno").param("status", "ok"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Volte ao app")));
    }
}
