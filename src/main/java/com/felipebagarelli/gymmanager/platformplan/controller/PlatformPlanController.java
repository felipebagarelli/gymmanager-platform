package com.felipebagarelli.gymmanager.platformplan.controller;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.PlatformPlanResponse;
import com.felipebagarelli.gymmanager.platformplan.dto.PlatformPlanDtos.SubscribeRequest;
import com.felipebagarelli.gymmanager.platformplan.service.PlatformPlanService;
import com.felipebagarelli.gymmanager.platformplan.service.PlatformWebhookService;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/** Plano da plataforma do aluno sem personal, o webhook da conta da plataforma e a pagina de retorno. */
@RestController
public class PlatformPlanController {

    private final PlatformPlanService planService;
    private final PlatformWebhookService webhookService;

    public PlatformPlanController(PlatformPlanService planService, PlatformWebhookService webhookService) {
        this.planService = planService;
        this.webhookService = webhookService;
    }

    @GetMapping("/api/v1/platform-plan")
    public PlatformPlanResponse status(@AuthenticationPrincipal Jwt jwt) {
        return planService.status(jwt.getSubject());
    }

    @PostMapping("/api/v1/platform-plan/subscribe")
    public UrlResponse subscribe(@RequestBody @Valid SubscribeRequest request, @AuthenticationPrincipal Jwt jwt) {
        return planService.subscribe(request.interval(), jwt.getSubject());
    }

    @PostMapping("/api/v1/platform-plan/cancel")
    public PlatformPlanResponse cancel(@AuthenticationPrincipal Jwt jwt) {
        return planService.cancel(jwt.getSubject());
    }

    @PostMapping("/api/v1/platform-plan/resume")
    public PlatformPlanResponse resume(@AuthenticationPrincipal Jwt jwt) {
        return planService.resume(jwt.getSubject());
    }

    @PostMapping("/api/v1/platform-plan/regularize")
    public UrlResponse regularize(@AuthenticationPrincipal Jwt jwt) {
        return planService.regularize(jwt.getSubject());
    }

    @PostMapping("/api/v1/billing/platform-webhook")
    public void webhook(@RequestBody String payload,
                        @RequestHeader(value = "Stripe-Signature", required = false) String signature) {
        webhookService.handle(payload, signature);
    }

    /** Para onde o checkout devolve a pessoa (no navegador). Nao confirma nada: quem confirma e o webhook. */
    @GetMapping(value = "/checkout/retorno", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> checkoutReturn(@RequestParam(required = false) String status) {
        boolean ok = "ok".equals(status);
        String title = ok ? "Tudo certo!" : "Assinatura não concluída";
        String text = ok
                ? "Recebemos sua assinatura. Volte ao app GymManager: em instantes ela aparece no seu Perfil."
                : "Nada foi cobrado. Você pode tentar de novo pelo app quando quiser.";
        String page = """
                <!doctype html>
                <html lang="pt-BR"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>%s · GymManager</title>
                <style>body{font-family:system-ui,sans-serif;max-width:520px;margin:0 auto;padding:32px 16px;line-height:1.5;color:#111;background:#fff}</style>
                </head><body><h1>%s</h1><p>%s</p></body></html>
                """.formatted(title, title, text);
        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(page);
    }
}
