package com.felipebagarelli.gymmanager.account.mail;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.mail.javamail.JavaMailSender;

@Configuration
public class MailConfig {

    /**
     * Com MAIL_HOST envia de verdade. Sem ele, em desenvolvimento, so registra no log (com o codigo, para
     * testar). Em producao (perfil prod) o servidor NAO sobe: sem e-mail ninguem confirma a conta, e o log
     * guardaria codigos de troca de senha.
     */
    @Bean
    public EmailSender emailSender(@Value("${spring.mail.host:}") String host,
                                   @Value("${app.mail.from}") String from,
                                   ObjectProvider<JavaMailSender> mailSender,
                                   Environment environment) {
        JavaMailSender sender = mailSender.getIfAvailable();
        if (host == null || host.isBlank() || sender == null) {
            if (environment.acceptsProfiles(Profiles.of("prod"))) {
                throw new IllegalStateException(
                        "MAIL_HOST nao configurado: em producao o envio de e-mail e obrigatorio (ver docs/DEPLOY.md).");
            }
            return new LoggingEmailSender();
        }
        return new SmtpEmailSender(sender, from);
    }
}
