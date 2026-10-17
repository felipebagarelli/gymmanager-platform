package com.felipebagarelli.gymmanager.account.mail;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Desenvolvimento (sem MAIL_HOST): o e-mail so aparece no log do servidor. */
public class LoggingEmailSender implements EmailSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingEmailSender.class);

    @Override
    public void send(String to, String subject, String text) {
        log.warn("E-mail NAO enviado (MAIL_HOST nao configurado). Para: {} | Assunto: {}\n{}", to, subject, text);
    }
}
