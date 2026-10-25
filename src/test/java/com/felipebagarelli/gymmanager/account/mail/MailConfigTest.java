package com.felipebagarelli.gymmanager.account.mail;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mock.env.MockEnvironment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class MailConfigTest {

    @SuppressWarnings("unchecked")
    private static ObjectProvider<JavaMailSender> provider(JavaMailSender sender) {
        ObjectProvider<JavaMailSender> provider = mock(ObjectProvider.class);
        when(provider.getIfAvailable()).thenReturn(sender);
        return provider;
    }

    @Test
    void withoutMailHost_devOnlyLogs_prodRefusesToStart() {
        MockEnvironment dev = new MockEnvironment();
        assertThat(new MailConfig().emailSender("", "x@y", provider(null), dev)).isInstanceOf(LoggingEmailSender.class);

        MockEnvironment prod = new MockEnvironment();
        prod.setActiveProfiles("prod");
        assertThatThrownBy(() -> new MailConfig().emailSender("", "x@y", provider(null), prod))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("MAIL_HOST");
    }

    @Test
    void withMailHost_sendsForReal() {
        MockEnvironment prod = new MockEnvironment();
        prod.setActiveProfiles("prod");
        assertThat(new MailConfig().emailSender("smtp.example.com", "x@y", provider(mock(JavaMailSender.class)), prod))
                .isInstanceOf(SmtpEmailSender.class);
    }
}
