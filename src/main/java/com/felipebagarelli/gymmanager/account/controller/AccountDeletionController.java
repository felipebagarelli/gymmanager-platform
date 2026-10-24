package com.felipebagarelli.gymmanager.account.controller;

import com.felipebagarelli.gymmanager.account.service.AccountDeletionService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.util.HtmlUtils;

/** Exclusao da conta: no app (com a senha) e a pagina na web exigida pelo Google Play. */
@RestController
public class AccountDeletionController {

    public record DeleteAccountRequest(String password) {
    }

    private final AccountDeletionService service;
    private final String supportEmail;

    public AccountDeletionController(AccountDeletionService service,
                                     @Value("${app.support-email:}") String supportEmail) {
        this.service = service;
        this.supportEmail = supportEmail;
    }

    @PostMapping("/api/v1/me/delete")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteMyAccount(@RequestBody DeleteAccountRequest request, @AuthenticationPrincipal Jwt jwt) {
        service.deleteMyAccount(jwt.getSubject(), request.password());
    }

    /** Para quem nao tem mais o app instalado (exigencia do Google Play). */
    @GetMapping(value = "/conta/excluir", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> deletionPage() {
        String contact = supportEmail == null || supportEmail.isBlank()
                ? ""
                : "<p>Sem acesso ao app? Envie um e-mail para <a href=\"mailto:" + HtmlUtils.htmlEscape(supportEmail) + "\">"
                + HtmlUtils.htmlEscape(supportEmail) + "</a> a partir do e-mail da sua conta, pedindo a exclusão. "
                + "Respondemos em até 15 dias.</p>";
        String page = """
                <!doctype html>
                <html lang="pt-BR"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Excluir conta · GymManager</title>
                <style>body{font-family:system-ui,sans-serif;max-width:560px;margin:0 auto;padding:32px 16px;line-height:1.5;color:#111;background:#fff}</style>
                </head><body>
                <h1>Excluir sua conta do GymManager</h1>
                <p>No app: <strong>Perfil &rarr; Excluir conta</strong>, e confirme com a sua senha.</p>
                %s
                <p>O que acontece: as cobranças são canceladas; seus dados de cadastro, de saúde e as conversas são apagados;
                o histórico de treinos fica sem nenhuma identificação. O registro de que você aceitou os termos é guardado,
                como exige a lei.</p>
                </body></html>
                """.formatted(contact);
        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(page);
    }
}
