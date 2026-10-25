package com.felipebagarelli.gymmanager.invite.controller;

import com.felipebagarelli.gymmanager.auth.service.IpRateLimiter;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.invite.dto.InviteDtos.InviteLinkResponse;
import com.felipebagarelli.gymmanager.invite.dto.InviteDtos.InvitePreview;
import com.felipebagarelli.gymmanager.invite.service.InviteService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.util.HtmlUtils;

import java.text.NumberFormat;
import java.util.Locale;

/** Link de convite do plano (F5): o personal gera; quem recebe ve o plano e assina pelo app. */
@RestController
public class InviteController {

    private final InviteService inviteService;
    private final IpRateLimiter ipLimiter;

    public InviteController(InviteService inviteService, IpRateLimiter ipLimiter) {
        this.inviteService = inviteService;
        this.ipLimiter = ipLimiter;
    }

    @PostMapping("/api/v1/plans/{id}/invite")
    public InviteLinkResponse link(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return inviteService.link(id, jwt.getSubject());
    }

    @PostMapping("/api/v1/plans/{id}/invite/reset")
    public InviteLinkResponse reset(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return inviteService.reset(id, jwt.getSubject());
    }

    /** Publico (o app mostra o plano antes de pedir login). Limitado por IP contra varredura de codigos. */
    @GetMapping("/api/v1/invites/{code}")
    public InvitePreview preview(@PathVariable String code, HttpServletRequest http) {
        ipLimiter.check("invite", http.getRemoteAddr(), 60);
        return inviteService.preview(code);
    }

    @PostMapping("/api/v1/invites/{code}/accept")
    public UrlResponse accept(@PathVariable String code, @AuthenticationPrincipal Jwt jwt) {
        return inviteService.accept(code, jwt.getSubject());
    }

    /** Pagina que o link abre no navegador: o plano, o codigo e como entrar pelo app. */
    @GetMapping(value = "/convite/{code}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> page(@PathVariable String code, HttpServletRequest http) {
        ipLimiter.check("invite", http.getRemoteAddr(), 60);
        InvitePreview invite;
        try {
            invite = inviteService.preview(code);
        } catch (ResourceNotFoundException notFound) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).contentType(MediaType.TEXT_HTML)
                    .body(html("Convite não encontrado", "<h1>Convite não encontrado</h1><p>Este link não vale mais. Peça um link novo ao seu personal.</p>"));
        }
        String price = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("pt-BR")).format(invite.priceCents() / 100.0);
        String esc = HtmlUtils.htmlEscape(invite.code());
        StringBuilder body = new StringBuilder();
        body.append("<p class=muted>Convite de</p><h1>").append(HtmlUtils.htmlEscape(invite.trainerName())).append("</h1>");
        if (invite.headline() != null) body.append("<p>").append(HtmlUtils.htmlEscape(invite.headline())).append("</p>");
        body.append("<div class=card><h2>").append(HtmlUtils.htmlEscape(invite.planName())).append("</h2><p class=price>")
                .append(HtmlUtils.htmlEscape(price)).append(" / mês</p>");
        if (invite.planDescription() != null) body.append("<p>").append(HtmlUtils.htmlEscape(invite.planDescription())).append("</p>");
        body.append("</div>");
        body.append("<a class=button href=\"gymmanager://app/convite/").append(esc).append("\">Abrir no app GymManager</a>");
        body.append("<p>Ainda não tem o app? Instale o <strong>GymManager</strong>, crie sua conta e, em <strong>Mensagens → Tenho um código de convite</strong>, use o código:</p>");
        body.append("<p class=code>").append(esc).append("</p>");
        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(html("Convite · GymManager", body.toString()));
    }

    private static String html(String title, String body) {
        return """
                <!doctype html>
                <html lang="pt-BR"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>%s</title>
                <style>
                body{font-family:system-ui,sans-serif;max-width:480px;margin:0 auto;padding:32px 16px;line-height:1.5;color:#111;background:#fff}
                .muted{color:#666;margin:0}.card{border:1px solid #ddd;border-radius:16px;padding:16px;margin:16px 0}
                .price{font-size:1.4em;font-weight:700;margin:4px 0}
                .button{display:block;text-align:center;background:#c8f04a;color:#111;font-weight:700;padding:14px;border-radius:999px;text-decoration:none}
                .code{font-family:monospace;font-size:1.6em;letter-spacing:.1em;text-align:center;background:#f3f3f3;border-radius:12px;padding:10px}
                </style></head><body>%s</body></html>
                """.formatted(HtmlUtils.htmlEscape(title), body);
    }
}
