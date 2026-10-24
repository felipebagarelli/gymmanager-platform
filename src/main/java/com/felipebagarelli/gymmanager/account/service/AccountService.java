package com.felipebagarelli.gymmanager.account.service;

import com.felipebagarelli.gymmanager.account.dto.AccountDtos.RegisterStudentRequest;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.RegisterStudentResponse;
import com.felipebagarelli.gymmanager.account.dto.AccountDtos.VerifyEmailResponse;
import com.felipebagarelli.gymmanager.account.entity.AccountToken;
import com.felipebagarelli.gymmanager.account.entity.LegalAcceptance;
import com.felipebagarelli.gymmanager.account.entity.LegalDocument;
import com.felipebagarelli.gymmanager.account.entity.TokenPurpose;
import com.felipebagarelli.gymmanager.account.mail.EmailSender;
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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Period;
import java.util.Locale;
import java.util.Optional;

/**
 * Cadastro aberto do aluno (Fase C): conta, aceites registrados, confirmacao de e-mail,
 * troca de senha esquecida e autorizacao do responsavel (12 a 17 anos).
 * As respostas de "reenviar" e "esqueci a senha" nunca revelam se o e-mail existe.
 */
@Service
public class AccountService {

    public static final int MINIMUM_AGE = 12;
    public static final int ADULT_AGE = 18;

    private static final Logger log = LoggerFactory.getLogger(AccountService.class);

    private final UserRepository userRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final LegalAcceptanceRepository acceptanceRepository;
    private final AccountTokenService tokenService;
    private final EmailSender emailSender;
    private final PasswordEncoder passwordEncoder;
    private final LoginAttemptLimiter loginAttemptLimiter;
    private final String termsVersion;
    private final String publicUrl;
    private final Clock clock;

    @Autowired
    public AccountService(UserRepository userRepository,
                          StudentProfileRepository studentProfileRepository,
                          LegalAcceptanceRepository acceptanceRepository,
                          AccountTokenService tokenService,
                          EmailSender emailSender,
                          PasswordEncoder passwordEncoder,
                          LoginAttemptLimiter loginAttemptLimiter,
                          @Value("${app.legal.terms-version}") String termsVersion,
                          @Value("${app.public-url}") String publicUrl) {
        this(userRepository, studentProfileRepository, acceptanceRepository, tokenService, emailSender,
                passwordEncoder, loginAttemptLimiter, termsVersion, publicUrl, Clock.systemDefaultZone());
    }

    AccountService(UserRepository userRepository,
                   StudentProfileRepository studentProfileRepository,
                   LegalAcceptanceRepository acceptanceRepository,
                   AccountTokenService tokenService,
                   EmailSender emailSender,
                   PasswordEncoder passwordEncoder,
                   LoginAttemptLimiter loginAttemptLimiter,
                   String termsVersion,
                   String publicUrl,
                   Clock clock) {
        this.userRepository = userRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.acceptanceRepository = acceptanceRepository;
        this.tokenService = tokenService;
        this.emailSender = emailSender;
        this.passwordEncoder = passwordEncoder;
        this.loginAttemptLimiter = loginAttemptLimiter;
        this.termsVersion = termsVersion;
        this.publicUrl = publicUrl.endsWith("/") ? publicUrl.substring(0, publicUrl.length() - 1) : publicUrl;
        this.clock = clock;
    }

    public String termsVersion() {
        return termsVersion;
    }

    private static String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }

    int ageOn(LocalDate birthDate, LocalDate today) {
        return Period.between(birthDate, today).getYears();
    }

    /** E-mail que falha nao desfaz o cadastro: a pessoa pode pedir para reenviar. */
    private void sendSafely(String to, String subject, String text) {
        try {
            emailSender.send(to, subject, text);
        } catch (RuntimeException e) {
            log.warn("Falha ao enviar e-mail para {}: {}", to, e.getMessage());
        }
    }

    private void record(User user, LegalDocument document, String ip, String userAgent, String guardianName, String guardianEmail) {
        acceptanceRepository.save(LegalAcceptance.builder()
                .user(user)
                .document(document)
                .version(termsVersion)
                .acceptedAt(now())
                .ip(truncate(ip, 64))
                .userAgent(truncate(userAgent, 255))
                .guardianName(guardianName)
                .guardianEmail(guardianEmail)
                .build());
    }

    private static String truncate(String value, int max) {
        return value == null || value.length() <= max ? value : value.substring(0, max);
    }

    /** "ma***@gmail.com": mostra para quem foi o pedido sem expor o e-mail inteiro. */
    static String mask(String email) {
        if (email == null) return null;
        int at = email.indexOf('@');
        if (at <= 0) return "***";
        String name = email.substring(0, at);
        return name.substring(0, Math.min(2, name.length())) + "***" + email.substring(at);
    }

    private static String firstName(String name) {
        String trimmed = name == null ? "" : name.trim();
        int space = trimmed.indexOf(' ');
        return space > 0 ? trimmed.substring(0, space) : trimmed;
    }

    // ------------------------------------------------------------------ cadastro

    @Transactional
    public RegisterStudentResponse registerStudent(RegisterStudentRequest request, String ip, String userAgent) {
        if (!termsVersion.equals(request.termsVersion())) {
            throw new ConflictException("Os termos foram atualizados. Leia e aceite a versão atual para continuar.");
        }
        String email = normalize(request.email());
        LocalDate today = LocalDate.now(clock);
        if (request.birthDate().isAfter(today)) {
            throw new BadRequestException("Data de nascimento inválida.");
        }
        int age = ageOn(request.birthDate(), today);
        if (age < MINIMUM_AGE) {
            throw new BadRequestException("É preciso ter pelo menos " + MINIMUM_AGE + " anos para usar o GymManager.");
        }
        if (age > 120) {
            throw new BadRequestException("Data de nascimento inválida.");
        }
        boolean minor = age < ADULT_AGE;
        String guardianName = null;
        String guardianEmail = null;
        if (minor) {
            guardianName = request.guardianName() == null ? "" : request.guardianName().trim();
            guardianEmail = normalize(request.guardianEmail());
            if (guardianName.isEmpty() || guardianEmail.isEmpty()) {
                throw new BadRequestException("Quem tem menos de 18 anos precisa informar o nome e o e-mail de um responsável.");
            }
            if (guardianEmail.equals(email)) {
                throw new BadRequestException("O e-mail do responsável precisa ser diferente do seu.");
            }
        }
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new EmailAlreadyInUseException("Este e-mail já tem conta. Entre ou recupere a senha.");
        }

        LocalDateTime now = now();
        User user = userRepository.save(User.builder()
                .email(email)
                .passwordHash(passwordEncoder.encode(request.password()))
                .role(Role.STUDENT)
                .active(true)
                .createdAt(now)
                .updatedAt(now)
                .build());
        studentProfileRepository.save(StudentProfile.builder()
                .user(user)
                .name(request.name().trim())
                .birthDate(request.birthDate())
                .active(true)
                .guardianName(guardianName)
                .guardianEmail(guardianEmail)
                .build());

        record(user, LegalDocument.TERMS, ip, userAgent, null, null);
        record(user, LegalDocument.PRIVACY, ip, userAgent, null, null);
        record(user, LegalDocument.HEALTH_DATA, ip, userAgent, null, null);

        sendVerificationCode(user, request.name());
        return new RegisterStudentResponse(email, minor);
    }

    private void sendVerificationCode(User user, String name) {
        String code = tokenService.issueCode(user, TokenPurpose.VERIFY_EMAIL);
        sendSafely(user.getEmail(), "Seu código do GymManager: " + code, """
                Olá, %s!

                Seu código para confirmar o e-mail no GymManager é:

                    %s

                Ele vale por 30 minutos. Se você não criou uma conta, ignore este e-mail.
                """.formatted(firstName(name), code));
    }

    // ------------------------------------------------------------------ confirmar e-mail

    @Transactional(noRollbackFor = BadRequestException.class)
    public VerifyEmailResponse verifyEmail(String rawEmail, String code) {
        User user = userRepository.findByEmailIgnoreCase(normalize(rawEmail))
                .orElseThrow(() -> new BadRequestException("Código incorreto."));
        if (user.getEmailVerifiedAt() == null) {
            tokenService.consumeCode(user, TokenPurpose.VERIFY_EMAIL, code);
            user.setEmailVerifiedAt(now());
            user.setUpdatedAt(now());
            userRepository.save(user);
        }
        Optional<StudentProfile> student = studentProfileRepository.findByUserEmail(user.getEmail());
        if (student.isPresent() && guardianPending(student.get())) {
            // so pede ao responsavel depois de confirmar que o e-mail e mesmo do aluno
            if (!tokenService.inCooldown(user, TokenPurpose.GUARDIAN_CONSENT)) {
                sendGuardianRequest(user, student.get());
            }
            return new VerifyEmailResponse(true, mask(student.get().getGuardianEmail()));
        }
        return new VerifyEmailResponse(false, null);
    }

    /** Sempre "ok" para quem chama: nao revela se o e-mail existe nem se ja foi confirmado. */
    @Transactional
    public void resendVerification(String rawEmail) {
        userRepository.findByEmailIgnoreCase(normalize(rawEmail))
                .filter(u -> u.isActive() && u.getEmailVerifiedAt() == null)
                .filter(u -> !tokenService.inCooldown(u, TokenPurpose.VERIFY_EMAIL))
                .ifPresent(u -> sendVerificationCode(u,
                        studentProfileRepository.findByUserEmail(u.getEmail()).map(StudentProfile::getName).orElse("")));
    }

    // ------------------------------------------------------------------ responsavel

    static boolean guardianPending(StudentProfile student) {
        return student.getGuardianEmail() != null && student.getGuardianConsentAt() == null;
    }

    private void sendGuardianRequest(User user, StudentProfile student) {
        String token = tokenService.issueLink(user, TokenPurpose.GUARDIAN_CONSENT);
        String link = publicUrl + "/consent/guardian?token=" + token;
        sendSafely(student.getGuardianEmail(), firstName(student.getName()) + " pediu sua autorização no GymManager", """
                Olá, %s!

                %s (%s) criou uma conta no GymManager, um aplicativo para registrar e acompanhar treinos
                de musculação, e informou você como responsável.

                Como %s tem menos de 18 anos, a conta só é liberada com a sua autorização. O app guarda
                dados de treino e de saúde (como peso, altura e respostas sobre condições de saúde), usados
                apenas para montar e acompanhar os treinos.

                Para ler os detalhes e autorizar, abra o link abaixo (vale por 7 dias):

                %s

                Se você não conhece esse pedido, ignore este e-mail: a conta continua bloqueada.
                """.formatted(firstName(student.getGuardianName()), student.getName(), user.getEmail(),
                firstName(student.getName()), link));
    }

    /** Reenvia o pedido ao responsavel (e-mail ja confirmado). Sempre "ok" para quem chama. */
    @Transactional
    public void resendGuardianRequest(String rawEmail) {
        userRepository.findByEmailIgnoreCase(normalize(rawEmail))
                .filter(u -> u.isActive() && u.getEmailVerifiedAt() != null)
                .filter(u -> !tokenService.inCooldown(u, TokenPurpose.GUARDIAN_CONSENT))
                .ifPresent(u -> studentProfileRepository.findByUserEmail(u.getEmail())
                        .filter(AccountService::guardianPending)
                        .ifPresent(s -> sendGuardianRequest(u, s)));
    }

    /** Dados para a pagina de autorizacao (link ainda valido). */
    public Optional<StudentProfile> guardianRequest(String token) {
        return tokenService.peekLink(token, TokenPurpose.GUARDIAN_CONSENT)
                .flatMap(t -> studentProfileRepository.findByUserEmail(t.getUser().getEmail()))
                .filter(AccountService::guardianPending);
    }

    @Transactional
    public StudentProfile approveGuardian(String token, String ip, String userAgent) {
        AccountToken link = tokenService.consumeLink(token, TokenPurpose.GUARDIAN_CONSENT);
        StudentProfile student = studentProfileRepository.findByUserEmail(link.getUser().getEmail())
                .orElseThrow(() -> new BadRequestException("Este link expirou ou já foi usado."));
        if (student.getGuardianConsentAt() == null) {
            student.setGuardianConsentAt(now());
            studentProfileRepository.save(student);
            record(link.getUser(), LegalDocument.GUARDIAN_CONSENT, ip, userAgent, student.getGuardianName(), student.getGuardianEmail());
        }
        return student;
    }

    // ------------------------------------------------------------------ esqueci a senha

    @Transactional
    public void forgotPassword(String rawEmail) {
        userRepository.findByEmailIgnoreCase(normalize(rawEmail))
                .filter(User::isActive)
                .filter(u -> !tokenService.inCooldown(u, TokenPurpose.RESET_PASSWORD))
                .ifPresent(u -> {
                    String code = tokenService.issueCode(u, TokenPurpose.RESET_PASSWORD);
                    sendSafely(u.getEmail(), "Código para trocar a senha: " + code, """
                            Recebemos um pedido para trocar a senha da sua conta no GymManager.

                            Seu código é:

                                %s

                            Ele vale por 30 minutos. Se não foi você, ignore este e-mail: sua senha continua a mesma.
                            """.formatted(code));
                });
    }

    @Transactional(noRollbackFor = BadRequestException.class)
    public void resetPassword(String rawEmail, String code, String newPassword) {
        User user = userRepository.findByEmailIgnoreCase(normalize(rawEmail))
                .filter(User::isActive)
                .orElseThrow(() -> new BadRequestException("Código incorreto."));
        tokenService.consumeCode(user, TokenPurpose.RESET_PASSWORD, code);
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        // encerra as sessoes abertas em outros aparelhos
        user.setPasswordChangedAt(now());
        // recebeu o codigo no e-mail: o e-mail e dele
        if (user.getEmailVerifiedAt() == null) {
            user.setEmailVerifiedAt(now());
        }
        user.setUpdatedAt(now());
        userRepository.save(user);
        loginAttemptLimiter.reset(user.getEmail());
    }
}
