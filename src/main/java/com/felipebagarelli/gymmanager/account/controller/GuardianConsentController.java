package com.felipebagarelli.gymmanager.account.controller;

import com.felipebagarelli.gymmanager.account.service.AccountService;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

import java.util.Optional;

/**
 * Pagina simples, aberta pelo link do e-mail, em que o responsavel le e autoriza a conta do
 * adolescente. O GET so mostra; quem autoriza e o POST do botao (leitores de e-mail que "clicam"
 * nos links nao autorizam nada).
 */
@RestController
public class GuardianConsentController {

    private final AccountService accountService;

    public GuardianConsentController(AccountService accountService) {
        this.accountService = accountService;
    }

    @GetMapping(value = "/consent/guardian", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> page(@RequestParam(required = false) String token) {
        Optional<StudentProfile> request = accountService.guardianRequest(token);
        if (request.isEmpty()) {
            return html("Link inválido", "<p>Este link expirou ou já foi usado. Peça ao adolescente para reenviar o pedido pelo app.</p>");
        }
        StudentProfile s = request.get();
        String name = e(s.getName());
        String body = """
                <p>Olá, %s.</p>
                <p><strong>%s</strong> (%s) criou uma conta no GymManager e informou você como responsável.</p>
                <p>O GymManager é um aplicativo para registrar e acompanhar treinos de musculação. Ele guarda:</p>
                <ul>
                  <li>dados de cadastro (nome, e-mail, data de nascimento);</li>
                  <li>treinos realizados, cargas e repetições;</li>
                  <li>dados de saúde informados pelo próprio usuário (como peso, altura e respostas sobre condições de saúde).</li>
                </ul>
                <p>Esses dados são usados apenas para montar e acompanhar os treinos. Pagamentos e treinos gerados por
                inteligência artificial dependem da sua aprovação. Você pode pedir a exclusão da conta a qualquer momento.</p>
                <p><strong>Exercício físico envolve riscos.</strong> Se houver alguma condição de saúde, procure avaliação
                médica antes de começar.</p>
                <form method="post" action="/consent/guardian">
                  <input type="hidden" name="token" value="%s">
                  <label><input type="checkbox" name="confirm" value="yes" required>
                    Sou responsável legal por %s e autorizo o uso do GymManager e o tratamento dos dados descritos acima.</label>
                  <p><button type="submit">Autorizar</button></p>
                </form>
                """.formatted(e(s.getGuardianName()), name, e(s.getUser().getEmail()), e(token), name);
        return html("Autorização do responsável", body);
    }

    @PostMapping(value = "/consent/guardian", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> approve(@RequestParam(required = false) String token,
                                          @RequestParam(required = false) String confirm,
                                          HttpServletRequest http) {
        if (!"yes".equals(confirm)) {
            return html("Autorização do responsável", "<p>Marque a confirmação para autorizar. Volte e tente de novo.</p>");
        }
        try {
            StudentProfile s = accountService.approveGuardian(token, http.getRemoteAddr(), http.getHeader("User-Agent"));
            return html("Autorizado", "<p>Pronto! A conta de <strong>" + e(s.getName())
                    + "</strong> foi liberada. Já pode entrar no app.</p>");
        } catch (BadRequestException ex) {
            return html("Link inválido", "<p>" + e(ex.getMessage()) + "</p>");
        }
    }

    private static String e(String value) {
        return value == null ? "" : HtmlUtils.htmlEscape(value);
    }

    private static ResponseEntity<String> html(String title, String body) {
        String page = """
                <!doctype html>
                <html lang="pt-BR"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>%s · GymManager</title>
                <style>
                  body{font-family:system-ui,sans-serif;max-width:560px;margin:0 auto;padding:24px 16px;line-height:1.5;color:#111;background:#fff}
                  h1{font-size:22px} button{font-size:16px;padding:12px 20px;border-radius:999px;border:0;background:#111;color:#fff}
                  label{display:block;margin-top:12px}
                </style></head>
                <body><h1>%s</h1>%s</body></html>
                """.formatted(e(title), e(title), body);
        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(page);
    }
}
