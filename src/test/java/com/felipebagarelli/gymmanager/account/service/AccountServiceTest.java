package com.felipebagarelli.gymmanager.account.service;

import com.felipebagarelli.gymmanager.account.dto.AccountDtos.RegisterStudentRequest;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.RegisterStudentResponse;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.VerifyEmailResponse;
import com.felipebagarelli.gymmanager.account.entity.AccountToken;
import com.felipebagarelli.gymmanager.account.entity.LegalAcceptance;
import com.felipebagarelli.gymmanager.account.entity.LegalDocument;
import com.felipebagarelli.gymmanager.account.entity.TokenPurpose;
import com.felipebagarelli.gymmanager.account.mail.EmailSender;
import com.felipebagarelli.gymmanager.account.repository.AccountTokenRepository;
import com.felipebagarelli.gymmanager.account.repository.LegalAcceptanceRepository;
import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.auth.service.LoginAttemptLimiter;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.EmailAlreadyInUseException;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Cadastro aberto: repositorios em memoria (mocks com estado) para exercitar o fluxo inteiro —
 * cadastro, codigo por e-mail, responsavel e troca de senha.
 */
class AccountServiceTest {

    private static final String TERMS = "2026-10-16";
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-16T12:00:00Z"), ZoneId.of("America/Sao_Paulo"));

    private final Map<String, User> users = new HashMap<>();
    private final Map<String, StudentProfile> students = new HashMap<>();
    private final List<AccountToken> tokens = new ArrayList<>();
    private final List<LegalAcceptance> acceptances = new ArrayList<>();
    private final List<String[]> sent = new ArrayList<>();
    private final AtomicLong ids = new AtomicLong(1);

    private AccountService service;
    private LoginAttemptLimiter limiter;

    @BeforeEach
    void setUp() {
        UserRepository userRepository = mock(UserRepository.class);
        when(userRepository.existsByEmailIgnoreCase(anyString())).thenAnswer(i -> users.containsKey(((String) i.getArgument(0)).toLowerCase()));
        when(userRepository.findByEmailIgnoreCase(anyString())).thenAnswer(i -> Optional.ofNullable(users.get(((String) i.getArgument(0)).toLowerCase())));
        when(userRepository.save(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            if (u.getId() == null) u.setId(ids.getAndIncrement());
            users.put(u.getEmail(), u);
            return u;
        });

        StudentProfileRepository studentRepository = mock(StudentProfileRepository.class);
        when(studentRepository.save(any(StudentProfile.class))).thenAnswer(i -> {
            StudentProfile s = i.getArgument(0);
            students.put(s.getUser().getEmail(), s);
            return s;
        });
        when(studentRepository.findByUserEmail(anyString())).thenAnswer(i -> Optional.ofNullable(students.get((String) i.getArgument(0))));

        AccountTokenRepository tokenRepository = mock(AccountTokenRepository.class);
        when(tokenRepository.save(any(AccountToken.class))).thenAnswer(i -> {
            AccountToken t = i.getArgument(0);
            if (!tokens.contains(t)) tokens.add(t);
            return t;
        });
        when(tokenRepository.findFirstByUserIdAndPurposeAndUsedAtIsNullOrderByCreatedAtDesc(anyLong(), any())).thenAnswer(i ->
                tokens.stream().filter(t -> t.getUser().getId().equals(i.getArgument(0)) && t.getPurpose() == i.getArgument(1) && t.getUsedAt() == null)
                        .reduce((a, b) -> b));
        when(tokenRepository.findByUserIdAndPurposeAndUsedAtIsNull(anyLong(), any())).thenAnswer(i ->
                tokens.stream().filter(t -> t.getUser().getId().equals(i.getArgument(0)) && t.getPurpose() == i.getArgument(1) && t.getUsedAt() == null).toList());
        when(tokenRepository.findByTokenHashAndPurpose(anyString(), any())).thenAnswer(i ->
                tokens.stream().filter(t -> t.getTokenHash().equals(i.getArgument(0)) && t.getPurpose() == i.getArgument(1)).findFirst());

        LegalAcceptanceRepository acceptanceRepository = mock(LegalAcceptanceRepository.class);
        when(acceptanceRepository.save(any(LegalAcceptance.class))).thenAnswer(i -> {
            acceptances.add(i.getArgument(0));
            return i.getArgument(0);
        });

        EmailSender emailSender = (to, subject, text) -> sent.add(new String[]{to, subject, text});
        org.springframework.security.crypto.password.PasswordEncoder encoder = mock(org.springframework.security.crypto.password.PasswordEncoder.class);
        when(encoder.encode(anyString())).thenAnswer(i -> "hash:" + i.getArgument(0));
        limiter = mock(LoginAttemptLimiter.class);

        service = new AccountService(userRepository, studentRepository, acceptanceRepository,
                new AccountTokenService(tokenRepository, clock), emailSender, encoder, limiter,
                TERMS, "https://api.gymmanager.test/", clock);
    }

    private RegisterStudentRequest adult(String email) {
        return new RegisterStudentRequest("Maria Aluna", email, "senhaSegura123", LocalDate.of(1995, 3, 21),
                null, null, TERMS, true, true);
    }

    private static String lastCode(List<String[]> sent) {
        Matcher m = Pattern.compile("(\\d{6})").matcher(sent.getLast()[2]);
        assertThat(m.find()).isTrue();
        return m.group(1);
    }

    @Test
    void register_createsUnverifiedStudent_recordsAcceptances_andEmailsACode() {
        RegisterStudentResponse response = service.registerStudent(adult("  Maria@Example.com "), "10.0.0.1", "app");

        assertThat(response.email()).isEqualTo("maria@example.com");
        assertThat(response.guardianRequired()).isFalse();
        User user = users.get("maria@example.com");
        assertThat(user.getRole()).isEqualTo(Role.STUDENT);
        assertThat(user.getEmailVerifiedAt()).isNull();
        assertThat(user.getPasswordHash()).isEqualTo("hash:senhaSegura123");
        assertThat(acceptances).extracting(LegalAcceptance::getDocument)
                .containsExactly(LegalDocument.TERMS, LegalDocument.PRIVACY, LegalDocument.HEALTH_DATA);
        assertThat(acceptances).allMatch(a -> a.getVersion().equals(TERMS) && "10.0.0.1".equals(a.getIp()));
        assertThat(sent.getLast()[0]).isEqualTo("maria@example.com");
        // o banco guarda so o hash do codigo
        assertThat(tokens.getLast().getTokenHash()).doesNotContain(lastCode(sent)).hasSize(64);
    }

    @Test
    void register_rules() {
        assertThatThrownBy(() -> service.registerStudent(new RegisterStudentRequest("A", "a@x.com", "senhaSegura123",
                LocalDate.of(1995, 1, 1), null, null, "versao-antiga", true, true), null, null))
                .isInstanceOf(ConflictException.class);
        // 11 anos
        assertThatThrownBy(() -> service.registerStudent(new RegisterStudentRequest("A", "a@x.com", "senhaSegura123",
                LocalDate.of(2015, 1, 1), null, null, TERMS, true, true), null, null))
                .isInstanceOf(BadRequestException.class).hasMessageContaining("12 anos");
        // 15 anos sem responsavel
        assertThatThrownBy(() -> service.registerStudent(new RegisterStudentRequest("A", "a@x.com", "senhaSegura123",
                LocalDate.of(2011, 1, 1), null, null, TERMS, true, true), null, null))
                .isInstanceOf(BadRequestException.class).hasMessageContaining("responsável");
        // responsavel com o mesmo e-mail
        assertThatThrownBy(() -> service.registerStudent(new RegisterStudentRequest("A", "a@x.com", "senhaSegura123",
                LocalDate.of(2011, 1, 1), "Ana", "A@x.com", TERMS, true, true), null, null))
                .isInstanceOf(BadRequestException.class).hasMessageContaining("diferente");

        service.registerStudent(adult("maria@example.com"), null, null);
        assertThatThrownBy(() -> service.registerStudent(adult("MARIA@example.com"), null, null))
                .isInstanceOf(EmailAlreadyInUseException.class);
    }

    @Test
    void verifyEmail_withTheRightCode_andLocksAfterTooManyWrongOnes() {
        service.registerStudent(adult("maria@example.com"), null, null);
        String code = lastCode(sent);

        assertThatThrownBy(() -> service.verifyEmail("maria@example.com", "000000".equals(code) ? "111111" : "000000"))
                .isInstanceOf(BadRequestException.class).hasMessage("Código incorreto.");
        assertThat(tokens.getLast().getAttempts()).isEqualTo(1);

        VerifyEmailResponse ok = service.verifyEmail("maria@example.com", code);
        assertThat(ok.guardianPending()).isFalse();
        assertThat(users.get("maria@example.com").getEmailVerifiedAt()).isNotNull();

        // codigo novo: 5 erros travam
        service.registerStudent(adult("bruno@example.com"), null, null);
        String wrong = "000000".equals(lastCode(sent)) ? "111111" : "000000";
        for (int i = 0; i < AccountTokenService.MAX_ATTEMPTS; i++) {
            assertThatThrownBy(() -> service.verifyEmail("bruno@example.com", wrong)).isInstanceOf(BadRequestException.class);
        }
        String right = lastCode(sent);
        assertThatThrownBy(() -> service.verifyEmail("bruno@example.com", right))
                .isInstanceOf(BadRequestException.class).hasMessageContaining("Muitas tentativas");
    }

    @Test
    void teen_afterVerifyingEmail_guardianGetsALink_andApprovingRecordsTheConsent() {
        RegisterStudentResponse response = service.registerStudent(new RegisterStudentRequest("Pedro Souza", "pedro@example.com",
                "senhaSegura123", LocalDate.of(2011, 5, 10), "Ana Souza", "Ana@Example.com", TERMS, true, true), "1.1.1.1", "app");
        assertThat(response.guardianRequired()).isTrue();
        assertThat(sent).hasSize(1); // ainda nao escreve ao responsavel

        VerifyEmailResponse verified = service.verifyEmail("pedro@example.com", lastCode(sent));
        assertThat(verified.guardianPending()).isTrue();
        assertThat(verified.guardianEmail()).isEqualTo("an***@example.com");
        assertThat(sent.getLast()[0]).isEqualTo("ana@example.com");

        Matcher link = Pattern.compile("token=([A-Za-z0-9_-]+)").matcher(sent.getLast()[2]);
        assertThat(link.find()).isTrue();
        assertThat(sent.getLast()[2]).contains("https://api.gymmanager.test/consent/guardian?token=");
        String token = link.group(1);

        assertThat(service.guardianRequest(token)).isPresent();
        StudentProfile approved = service.approveGuardian(token, "2.2.2.2", "browser");
        assertThat(approved.getGuardianConsentAt()).isNotNull();
        assertThat(acceptances.getLast().getDocument()).isEqualTo(LegalDocument.GUARDIAN_CONSENT);
        assertThat(acceptances.getLast().getGuardianEmail()).isEqualTo("ana@example.com");

        // link de uso unico
        assertThat(service.guardianRequest(token)).isEmpty();
        assertThatThrownBy(() -> service.approveGuardian(token, null, null)).isInstanceOf(BadRequestException.class);
    }

    @Test
    void forgotAndResetPassword() {
        service.registerStudent(adult("maria@example.com"), null, null);
        int before = sent.size();

        service.forgotPassword("desconhecido@example.com"); // nao revela, nao envia
        assertThat(sent).hasSize(before);

        service.forgotPassword("Maria@example.com");
        assertThat(sent).hasSize(before + 1);
        String code = lastCode(sent);

        service.forgotPassword("maria@example.com"); // dentro do intervalo de 1 minuto: nao reenvia
        assertThat(sent).hasSize(before + 1);

        service.resetPassword("maria@example.com", code, "novaSenha123");
        User user = users.get("maria@example.com");
        assertThat(user.getPasswordHash()).isEqualTo("hash:novaSenha123");
        assertThat(user.getEmailVerifiedAt()).isNotNull();

        assertThatThrownBy(() -> service.resetPassword("maria@example.com", code, "outraSenha123"))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> service.resetPassword("ninguem@example.com", "123456", "outraSenha123"))
                .isInstanceOf(BadRequestException.class).hasMessage("Código incorreto.");
        assertThat(tokens).filteredOn(t -> t.getPurpose() == TokenPurpose.RESET_PASSWORD).allMatch(t -> t.getUsedAt() != null);
    }

    @Test
    void maskGuardianEmail() {
        assertThat(AccountService.mask("ana@example.com")).isEqualTo("an***@example.com");
        assertThat(AccountService.mask("a@b.com")).isEqualTo("a***@b.com");
    }
}
