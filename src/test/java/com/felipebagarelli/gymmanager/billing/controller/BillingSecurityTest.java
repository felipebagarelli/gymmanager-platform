package com.felipebagarelli.gymmanager.billing.controller;

import com.felipebagarelli.gymmanager.auth.config.JwtConfig;
import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.service.JwtService;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.provider.InvalidWebhookException;
import com.felipebagarelli.gymmanager.billing.service.BillingWebhookService;
import com.felipebagarelli.gymmanager.billing.service.PayoutAccountService;
import com.felipebagarelli.gymmanager.billing.service.PlanService;
import com.felipebagarelli.gymmanager.billing.service.SubscriptionService;
import com.felipebagarelli.gymmanager.config.CorsConfig;
import com.felipebagarelli.gymmanager.config.SecurityConfig;
import com.felipebagarelli.gymmanager.exception.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = BillingController.class)
@Import({SecurityConfig.class, CorsConfig.class, JwtConfig.class, JwtService.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = {"jwt.secret=test-secret-used-only-in-billing-security-tests-1234567890", "app.cors.allowed-origins=http://localhost:5173"})
class BillingSecurityTest {

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JwtService jwtService;
    @MockitoBean
    private PlanService planService;
    @MockitoBean
    private PayoutAccountService payoutAccountService;
    @MockitoBean
    private SubscriptionService subscriptionService;
    @MockitoBean
    private BillingWebhookService webhookService;

    private String bearer(Role role) {
        return "Bearer " + jwtService.generateToken(User.builder().id(1L).email("u@example.com").role(role).active(true).build());
    }

    @Test
    void plans_areTrainerOnly() throws Exception {
        when(planService.mine(anyString())).thenReturn(List.of());
        mockMvc.perform(get("/api/v1/plans").header("Authorization", bearer(Role.TRAINER))).andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/plans").header("Authorization", bearer(Role.STUDENT))).andExpect(status().isForbidden());
        mockMvc.perform(get("/api/v1/plans")).andExpect(status().isUnauthorized());
    }

    @Test
    void availablePlansAndSubscriptions_areStudentOnly() throws Exception {
        when(planService.availableForStudent(anyString())).thenReturn(List.of());
        mockMvc.perform(get("/api/v1/plans/available").header("Authorization", bearer(Role.STUDENT))).andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/plans/available").header("Authorization", bearer(Role.TRAINER))).andExpect(status().isForbidden());
        mockMvc.perform(post("/api/v1/subscriptions").header("Authorization", bearer(Role.TRAINER))
                .contentType(MediaType.APPLICATION_JSON).content("{\"planId\":1}")).andExpect(status().isForbidden());
    }

    @Test
    void regularize_isStudentOnly() throws Exception {
        when(subscriptionService.regularize(anyString())).thenReturn(new UrlResponse("https://pay/invoice"));
        mockMvc.perform(post("/api/v1/subscriptions/me/regularize").header("Authorization", bearer(Role.STUDENT)))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/subscriptions/me/regularize").header("Authorization", bearer(Role.TRAINER)))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/v1/subscriptions/me/regularize")).andExpect(status().isUnauthorized());
    }

    @Test
    void payoutAccount_isTrainerOnly() throws Exception {
        mockMvc.perform(post("/api/v1/billing/payout-account/onboarding").header("Authorization", bearer(Role.STUDENT)))
                .andExpect(status().isForbidden());
    }

    @Test
    void createPlan_validatesPriceAndName() throws Exception {
        mockMvc.perform(post("/api/v1/plans").header("Authorization", bearer(Role.TRAINER))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"\",\"priceCents\":5}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void webhook_isPublic_butInvalidSignatureIs400() throws Exception {
        doNothing().when(webhookService).handle(any(), any());
        mockMvc.perform(post("/api/v1/billing/webhook").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isOk());

        doThrow(new InvalidWebhookException("Assinatura do webhook inválida.")).when(webhookService).handle(any(), any());
        mockMvc.perform(post("/api/v1/billing/webhook").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest());
    }
}
