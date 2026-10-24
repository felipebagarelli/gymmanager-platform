package com.felipebagarelli.gymmanager.account.service;

import com.felipebagarelli.gymmanager.account.repository.AccountTokenRepository;
import com.felipebagarelli.gymmanager.ai.repository.AiMessageRepository;
import com.felipebagarelli.gymmanager.aiworkout.repository.AiWorkoutProposalRepository;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.billing.provider.PaymentProvider;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.chat.repository.ConversationRepository;
import com.felipebagarelli.gymmanager.chat.repository.MessageRepository;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.onboarding.repository.HealthScreeningRepository;
import com.felipebagarelli.gymmanager.onboarding.repository.TrainingProfileRepository;
import com.felipebagarelli.gymmanager.platformplan.entity.PlatformSubscriptionStatus;
import com.felipebagarelli.gymmanager.platformplan.repository.PlatformSubscriptionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.student.service.StudentLinkService;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Exclusao da conta pelo proprio usuario (lojas e LGPD). Cancela as cobrancas, apaga os dados pessoais
 * e de saude, e anonimiza o que precisa ficar (sessoes de treino sem identificacao; os registros de
 * aceite dos termos ficam, por obrigacao de comprovacao). Encerra todas as sessoes abertas.
 */
@Service
public class AccountDeletionService {

    static final String DELETED_NAME = "Conta excluída";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final StudentProfileRepository studentRepository;
    private final TrainerProfileRepository trainerRepository;
    private final TrainerStudentRepository linkRepository;
    private final StudentLinkService linkService;
    private final PlatformSubscriptionRepository platformRepository;
    private final PaymentProvider paymentProvider;
    private final PlanRepository planRepository;
    private final AiMessageRepository aiMessageRepository;
    private final AiWorkoutProposalRepository proposalRepository;
    private final HealthScreeningRepository screeningRepository;
    private final TrainingProfileRepository trainingProfileRepository;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final AccountTokenRepository tokenRepository;

    public AccountDeletionService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                                  StudentProfileRepository studentRepository, TrainerProfileRepository trainerRepository,
                                  TrainerStudentRepository linkRepository, StudentLinkService linkService,
                                  PlatformSubscriptionRepository platformRepository, PaymentProvider paymentProvider,
                                  PlanRepository planRepository, AiMessageRepository aiMessageRepository,
                                  AiWorkoutProposalRepository proposalRepository, HealthScreeningRepository screeningRepository,
                                  TrainingProfileRepository trainingProfileRepository, ConversationRepository conversationRepository,
                                  MessageRepository messageRepository, AccountTokenRepository tokenRepository) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.studentRepository = studentRepository;
        this.trainerRepository = trainerRepository;
        this.linkRepository = linkRepository;
        this.linkService = linkService;
        this.platformRepository = platformRepository;
        this.paymentProvider = paymentProvider;
        this.planRepository = planRepository;
        this.aiMessageRepository = aiMessageRepository;
        this.proposalRepository = proposalRepository;
        this.screeningRepository = screeningRepository;
        this.trainingProfileRepository = trainingProfileRepository;
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.tokenRepository = tokenRepository;
    }

    @Transactional
    public void deleteMyAccount(String email, String password) {
        User user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new ResourceNotFoundException("Conta não encontrada!"));
        if (password == null || !passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new BadRequestException("Senha incorreta.");
        }
        trainerRepository.findByUserEmail(user.getEmail()).ifPresent(this::deleteTrainer);
        studentRepository.findByUserEmail(user.getEmail()).ifPresent(this::deleteStudent);

        tokenRepository.deleteByUserId(user.getId());
        LocalDateTime now = LocalDateTime.now();
        user.setEmail("excluida-" + user.getId() + "@conta-excluida.invalid");
        user.setPasswordHash(passwordEncoder.encode(UUID.randomUUID().toString()));
        user.setActive(false);
        user.setEmailVerifiedAt(null);
        user.setPasswordChangedAt(now);
        user.setUpdatedAt(now);
        userRepository.save(user);
    }

    private void deleteTrainer(TrainerProfile trainer) {
        boolean hasStudents = linkRepository.findByTrainerId(trainer.getId()).stream()
                .anyMatch(l -> l.getStatus() != TrainerStudentStatus.CANCELED);
        if (hasStudents) {
            throw new ConflictException("Antes de excluir a conta, desative seus alunos (eles voltam para o plano grátis do app).");
        }
        planRepository.findByTrainerIdOrderByPriceCentsAsc(trainer.getId()).forEach(plan -> {
            plan.setActive(false);
            planRepository.save(plan);
        });
        trainer.setDisplayName(DELETED_NAME);
        trainer.setPhone(null);
        trainer.setBio(null);
        trainer.setHeadline(null);
        trainer.setCity(null);
        trainer.setState(null);
        trainer.setSpecialties(null);
        trainer.setListed(false);
        trainerRepository.save(trainer);
    }

    private void deleteStudent(StudentProfile student) {
        // cobrancas: mensalidade com o personal e plano da plataforma
        linkRepository.findByStudentId(student.getId()).ifPresent(link -> {
            if (link.getStatus() != TrainerStudentStatus.CANCELED) {
                linkService.end(link);
            }
            conversationRepository.findByTrainerStudentId(link.getId())
                    .ifPresent(conversation -> messageRepository.deleteByConversationId(conversation.getId()));
        });
        platformRepository.findFirstByStudentIdOrderByIdDesc(student.getId())
                .filter(s -> s.getStatus() != PlatformSubscriptionStatus.CANCELED)
                .ifPresent(s -> {
                    if (s.getStripeSubscriptionId() != null) {
                        paymentProvider.cancelPlatformSubscription(s.getStripeSubscriptionId());
                    }
                    s.setStatus(PlatformSubscriptionStatus.CANCELED);
                    s.setUpdatedAt(LocalDateTime.now());
                    platformRepository.save(s);
                });
        // dados de saude e conversas com a IA
        aiMessageRepository.deleteByStudentId(student.getId());
        proposalRepository.deleteByStudentId(student.getId());
        screeningRepository.deleteByStudentId(student.getId());
        trainingProfileRepository.deleteByStudentId(student.getId());
        // cadastro anonimizado (as sessoes de treino ficam sem identificacao)
        student.setName(DELETED_NAME);
        student.setBirthDate(null);
        student.setPhone(null);
        student.setGoal(null);
        student.setHeight(null);
        student.setWeight(null);
        student.setWeeklyGoal(null);
        student.setGuardianName(null);
        student.setGuardianEmail(null);
        student.setShareHealthWithTrainer(false);
        student.setActive(false);
        studentRepository.save(student);
    }
}
