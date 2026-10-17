package com.felipebagarelli.gymmanager.account.mail;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;

@Configuration
public class MailConfig {

    /** Com MAIL_HOST envia de verdade; sem ele, so registra no log (o app sobe normalmente). */
    @Bean
    public EmailSender emailSender(@Value("${spring.mail.host:}") String host,
                                   @Value("${app.mail.from}") String from,
                                   ObjectProvider<JavaMailSender> mailSender) {
        JavaMailSender sender = mailSender.getIfAvailable();
        if (host == null || host.isBlank() || sender == null) {
            return new LoggingEmailSender();
        }
        return new SmtpEmailSender(sender, from);
    }
}
