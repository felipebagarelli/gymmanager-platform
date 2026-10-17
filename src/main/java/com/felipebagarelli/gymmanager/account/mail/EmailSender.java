package com.felipebagarelli.gymmanager.account.mail;

/**
 * Porta de envio de e-mail transacional. Trocar de fornecedor (Brevo, Resend, Amazon SES...)
 * nao muda o resto do sistema: todos aceitam SMTP, configurado por variavel de ambiente.
 */
public interface EmailSender {

    /** Envia um e-mail de texto simples. Lanca excecao se o fornecedor recusar. */
    void send(String to, String subject, String text);
}
