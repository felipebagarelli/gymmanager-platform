package com.felipebagarelli.gymmanager.billing.controller;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.*;
import com.felipebagarelli.gymmanager.billing.service.BillingWebhookService;
import com.felipebagarelli.gymmanager.billing.service.PayoutAccountService;
import com.felipebagarelli.gymmanager.billing.service.PlanService;
import com.felipebagarelli.gymmanager.billing.service.SubscriptionService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Planos e recebimento (personal), assinatura (aluno) e webhook do provedor (publico, com assinatura). */
@RestController
public class BillingController {

    private final PlanService planService;
    private final PayoutAccountService payoutAccountService;
    private final SubscriptionService subscriptionService;
    private final BillingWebhookService webhookService;

    public BillingController(PlanService planService, PayoutAccountService payoutAccountService,
                             SubscriptionService subscriptionService, BillingWebhookService webhookService) {
        this.planService = planService;
        this.payoutAccountService = payoutAccountService;
        this.subscriptionService = subscriptionService;
        this.webhookService = webhookService;
    }

    // ---- personal ----

    @GetMapping("/api/v1/plans")
    public List<PlanResponse> myPlans(@AuthenticationPrincipal Jwt jwt) {
        return planService.mine(jwt.getSubject());
    }

    @PostMapping("/api/v1/plans")
    @ResponseStatus(HttpStatus.CREATED)
    public PlanResponse createPlan(@RequestBody @Valid PlanRequest request, @AuthenticationPrincipal Jwt jwt) {
        return planService.create(request, jwt.getSubject());
    }

    @PutMapping("/api/v1/plans/{id}")
    public PlanResponse updatePlan(@PathVariable Long id, @RequestBody @Valid PlanRequest request,
                                   @AuthenticationPrincipal Jwt jwt) {
        return planService.update(id, request, jwt.getSubject());
    }

    @DeleteMapping("/api/v1/plans/{id}")
    public void deactivatePlan(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        planService.deactivate(id, jwt.getSubject());
    }

    @GetMapping("/api/v1/billing/payout-account")
    public PayoutAccountResponse payoutAccount(@AuthenticationPrincipal Jwt jwt) {
        return payoutAccountService.status(jwt.getSubject());
    }

    @PostMapping("/api/v1/billing/payout-account/onboarding")
    public UrlResponse onboarding(@AuthenticationPrincipal Jwt jwt) {
        return payoutAccountService.startOnboarding(jwt.getSubject());
    }

    @GetMapping("/api/v1/billing/subscriptions")
    public List<SubscriptionResponse> trainerSubscriptions(@AuthenticationPrincipal Jwt jwt) {
        return subscriptionService.forTrainer(jwt.getSubject());
    }

    // ---- aluno ----

    @GetMapping("/api/v1/plans/available")
    public List<PlanResponse> availablePlans(@AuthenticationPrincipal Jwt jwt) {
        return planService.availableForStudent(jwt.getSubject());
    }

    @PostMapping("/api/v1/subscriptions")
    public UrlResponse subscribe(@RequestBody @Valid SubscribeRequest request, @AuthenticationPrincipal Jwt jwt) {
        return subscriptionService.subscribe(request.planId(), jwt.getSubject());
    }

    /** 204 quando o aluno ainda nao tem assinatura. */
    @GetMapping("/api/v1/subscriptions/me")
    public ResponseEntity<SubscriptionResponse> mySubscription(@AuthenticationPrincipal Jwt jwt) {
        return subscriptionService.mine(jwt.getSubject())
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.noContent().build());
    }

    @PostMapping("/api/v1/subscriptions/me/cancel")
    public SubscriptionResponse cancel(@AuthenticationPrincipal Jwt jwt) {
        return subscriptionService.cancel(jwt.getSubject());
    }

    // ---- provedor ----

    @PostMapping("/api/v1/billing/webhook")
    public void webhook(@RequestBody String payload,
                        @RequestHeader(value = "Stripe-Signature", required = false) String signature) {
        webhookService.handle(payload, signature);
    }
}
