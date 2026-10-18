package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.ai.provider.AiProvider;
import com.felipebagarelli.gymmanager.ai.provider.AiReply;
import com.felipebagarelli.gymmanager.ai.provider.AiRequest;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.EligibilityResponse;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposalContent;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposalResponse;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposedExercise;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.ProposedWorkout;
import com.felipebagarelli.gymmanager.aiworkout.entity.AiWorkoutProposal;
import com.felipebagarelli.gymmanager.aiworkout.entity.ProposalStatus;
import com.felipebagarelli.gymmanager.aiworkout.repository.AiWorkoutProposalRepository;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.onboarding.entity.HealthScreening;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import com.felipebagarelli.gymmanager.onboarding.repository.HealthScreeningRepository;
import com.felipebagarelli.gymmanager.onboarding.repository.TrainingProfileRepository;
import com.felipebagarelli.gymmanager.platformplan.service.PlatformPlanService;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Period;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * A IA propoe, o aluno decide (Fase D). Regras: so aluno adulto sem personal, com onboarding feito e
 * triagem de saude sem risco; limite mensal (gratis/Pro); proposta validada pelo servidor; nada vira
 * treino antes do aceite, e o aceite cria os treinos pela mesma via dos treinos do aluno.
 */
@Service
public class AiWorkoutProposalService {

    static final Duration PROPOSAL_TTL = Duration.ofDays(7);
    static final long MAX_TOKENS = 4000;
    private static final int ADULT_AGE = 18;

    private final AiProvider aiProvider;
    private final AiWorkoutProposalRepository repository;
    private final StudentProfileRepository studentProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;
    private final TrainingProfileRepository trainingProfileRepository;
    private final HealthScreeningRepository screeningRepository;
    private final ExerciseRepository exerciseRepository;
    private final WorkoutRepository workoutRepository;
    private final WorkoutExercisesRepository workoutExercisesRepository;
    private final WorkoutAssignmentRepository assignmentRepository;
    private final PlatformPlanService platformPlanService;
    private final int freePerMonth;
    private final int proPerMonth;
    private final Clock clock;

    @Autowired
    public AiWorkoutProposalService(AiProvider aiProvider, AiWorkoutProposalRepository repository,
                                    StudentProfileRepository studentProfileRepository,
                                    TrainerStudentRepository trainerStudentRepository,
                                    TrainingProfileRepository trainingProfileRepository,
                                    HealthScreeningRepository screeningRepository,
                                    ExerciseRepository exerciseRepository,
                                    WorkoutRepository workoutRepository,
                                    WorkoutExercisesRepository workoutExercisesRepository,
                                    WorkoutAssignmentRepository assignmentRepository,
                                    PlatformPlanService platformPlanService,
                                    @Value("${app.ai.proposals.free-per-month:1}") int freePerMonth,
                                    @Value("${app.ai.proposals.pro-per-month:30}") int proPerMonth) {
        this(aiProvider, repository, studentProfileRepository, trainerStudentRepository, trainingProfileRepository,
                screeningRepository, exerciseRepository, workoutRepository, workoutExercisesRepository, assignmentRepository,
                platformPlanService, freePerMonth, proPerMonth, Clock.systemDefaultZone());
    }

    AiWorkoutProposalService(AiProvider aiProvider, AiWorkoutProposalRepository repository,
                             StudentProfileRepository studentProfileRepository,
                             TrainerStudentRepository trainerStudentRepository,
                             TrainingProfileRepository trainingProfileRepository,
                             HealthScreeningRepository screeningRepository,
                             ExerciseRepository exerciseRepository,
                             WorkoutRepository workoutRepository,
                             WorkoutExercisesRepository workoutExercisesRepository,
                             WorkoutAssignmentRepository assignmentRepository,
                             PlatformPlanService platformPlanService,
                             int freePerMonth, int proPerMonth, Clock clock) {
        this.aiProvider = aiProvider;
        this.repository = repository;
        this.studentProfileRepository = studentProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
        this.trainingProfileRepository = trainingProfileRepository;
        this.screeningRepository = screeningRepository;
        this.exerciseRepository = exerciseRepository;
        this.workoutRepository = workoutRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
        this.assignmentRepository = assignmentRepository;
        this.platformPlanService = platformPlanService;
        this.freePerMonth = freePerMonth;
        this.proPerMonth = proPerMonth;
        this.clock = clock;
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }

    private StudentProfile studentOf(String email) {
        return studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
    }

    private long usedThisMonth(StudentProfile student) {
        LocalDateTime monthStart = LocalDate.now(clock).withDayOfMonth(1).atStartOfDay();
        return repository.countByStudentIdAndCreatedAtGreaterThanEqual(student.getId(), monthStart);
    }

    /** Motivo e codigo quando nao pode (null = pode). A ordem importa: o mais grave primeiro. */
    private String[] blocker(StudentProfile student, boolean pro, long used) {
        boolean withTrainer = trainerStudentRepository.findByStudentId(student.getId())
                .map(l -> l.getStatus() == TrainerStudentStatus.ACTIVE || l.getStatus() == TrainerStudentStatus.PAUSED)
                .orElse(false);
        if (withTrainer) {
            return new String[]{"HAS_TRAINER", "Quem monta seus treinos é o seu personal."};
        }
        if (student.getBirthDate() == null || Period.between(student.getBirthDate(), LocalDate.now(clock)).getYears() < ADULT_AGE) {
            return new String[]{"MINOR", "Para menores de 18 anos, o treino pela IA depende da aprovação do responsável (em breve)."};
        }
        if (trainingProfileRepository.findByStudentId(student.getId()).isEmpty()) {
            return new String[]{"NO_PROFILE", "Complete o seu perfil de treino primeiro."};
        }
        Optional<HealthScreening> screening = screeningRepository.findFirstByStudentIdOrderByAnsweredAtDescIdDesc(student.getId());
        if (screening.isEmpty()) {
            return new String[]{"NO_SCREENING", "Responda a triagem de saúde primeiro."};
        }
        if (screening.get().isRisk()) {
            return new String[]{"HEALTH_RISK",
                    "Pela sua triagem de saúde, o app não monta treinos automáticos. Procure uma avaliação médica ou de um profissional de educação física."};
        }
        int limit = pro ? proPerMonth : freePerMonth;
        if (used >= limit) {
            return new String[]{pro ? "PRO_LIMIT" : "FREE_LIMIT", pro
                    ? "Você atingiu o limite de propostas deste mês. Volte no mês que vem."
                    : "Você já usou a proposta grátis deste mês. Com o Pro, você gera quantas precisar."};
        }
        return null;
    }

    public EligibilityResponse eligibility(String email) {
        StudentProfile student = studentOf(email);
        boolean pro = platformPlanService.isPro(student);
        long used = usedThisMonth(student);
        String[] blocked = blocker(student, pro, used);
        return new EligibilityResponse(blocked == null, blocked == null ? null : blocked[1], blocked == null ? null : blocked[0],
                used, pro ? proPerMonth : freePerMonth, pro);
    }

    /** Pede a proposta a IA (fora de transacao); so grava e conta se vier uma proposta valida. */
    public ProposalResponse propose(String email, String note) {
        StudentProfile student = studentOf(email);
        boolean pro = platformPlanService.isPro(student);
        String[] blocked = blocker(student, pro, usedThisMonth(student));
        if (blocked != null) {
            throw new ConflictException(blocked[1]);
        }
        TrainingProfile profile = trainingProfileRepository.findByStudentId(student.getId()).orElseThrow();
        ProposalRules rules = ProposalRules.of(profile);
        Map<String, Exercises> catalog = new LinkedHashMap<>();
        for (Exercises e : exerciseRepository.findByTrainerIsNullOrderByNameAsc()) {
            if (e.getCatalogCode() != null && e.getEquipment() != null && rules.equipment().contains(e.getEquipment())) {
                catalog.put(e.getCatalogCode(), e);
            }
        }
        String cleanNote = note == null ? null : ProposalParser.clean(note, 300);

        AiReply reply = aiProvider.ask(new AiRequest(ProposalPromptBuilder.system(profile, rules, catalog.values()),
                List.of(), ProposalPromptBuilder.question(cleanNote), null, MAX_TOKENS));
        ProposalContent content = ProposalParser.parse(reply.text(), catalog, rules);

        AiWorkoutProposal saved = repository.save(AiWorkoutProposal.builder()
                .student(student)
                .status(ProposalStatus.PROPOSED)
                .requestNote(cleanNote == null || cleanNote.isEmpty() ? null : cleanNote)
                .proposalJson(ProposalParser.toJson(content))
                .inputTokens(reply.inputTokens())
                .outputTokens(reply.outputTokens())
                .createdAt(now())
                .build());
        return toResponse(saved);
    }

    public ProposalResponse get(String email, Long id) {
        return toResponse(expireIfOld(find(email, id)));
    }

    private AiWorkoutProposal find(String email, Long id) {
        return repository.findByIdAndStudentId(id, studentOf(email).getId())
                .orElseThrow(() -> new ResourceNotFoundException("Proposta não encontrada!"));
    }

    private AiWorkoutProposal expireIfOld(AiWorkoutProposal p) {
        if (p.getStatus() == ProposalStatus.PROPOSED && p.getCreatedAt().plus(PROPOSAL_TTL).isBefore(now())) {
            p.setStatus(ProposalStatus.EXPIRED);
            p.setDecidedAt(now());
            repository.save(p);
        }
        return p;
    }

    /** O aceite cria os treinos do aluno (com os exercicios ja validados) e os deixa ativos. */
    @Transactional
    public ProposalResponse accept(String email, Long id) {
        AiWorkoutProposal proposal = expireIfOld(find(email, id));
        if (proposal.getStatus() != ProposalStatus.PROPOSED) {
            throw new ConflictException("Esta proposta não está mais disponível. Gere uma nova.");
        }
        StudentProfile student = proposal.getStudent();
        boolean withTrainer = trainerStudentRepository.findByStudentId(student.getId())
                .map(l -> l.getStatus() == TrainerStudentStatus.ACTIVE || l.getStatus() == TrainerStudentStatus.PAUSED)
                .orElse(false);
        if (withTrainer) {
            throw new ConflictException("Quem monta seus treinos é o seu personal.");
        }
        ProposalContent content = ProposalParser.fromJson(proposal.getProposalJson());
        List<Long> created = new ArrayList<>();
        for (ProposedWorkout w : content.workouts()) {
            Workout workout = workoutRepository.save(Workout.builder().name(w.name()).studentOwner(student).build());
            int position = 1;
            for (ProposedExercise e : w.exercises()) {
                Exercises exercise = exerciseRepository.findById(e.exerciseId())
                        .orElseThrow(() -> new ConflictException("Um exercício da proposta não existe mais. Gere uma nova."));
                workoutExercisesRepository.save(WorkoutExercises.builder()
                        .workout(workout)
                        .exercise(exercise)
                        .sets(e.sets())
                        .reps(e.reps())
                        .restSeconds(e.restSeconds())
                        .position(position++)
                        .notes(e.note() == null || e.note().isEmpty() ? null : e.note())
                        .build());
            }
            assignmentRepository.save(WorkoutAssignment.builder()
                    .workout(workout)
                    .student(student)
                    .status(WorkoutAssignmentStatus.ACTIVE)
                    .startedAt(now())
                    .build());
            created.add(workout.getId());
        }
        proposal.setStatus(ProposalStatus.ACCEPTED);
        proposal.setDecidedAt(now());
        proposal.setWorkoutIds(created.stream().map(String::valueOf).collect(Collectors.joining(",")));
        return toResponse(repository.save(proposal));
    }

    @Transactional
    public ProposalResponse reject(String email, Long id) {
        AiWorkoutProposal proposal = expireIfOld(find(email, id));
        if (proposal.getStatus() == ProposalStatus.PROPOSED) {
            proposal.setStatus(ProposalStatus.REJECTED);
            proposal.setDecidedAt(now());
            repository.save(proposal);
        }
        return toResponse(proposal);
    }

    private ProposalResponse toResponse(AiWorkoutProposal p) {
        List<Long> workoutIds = p.getWorkoutIds() == null || p.getWorkoutIds().isBlank()
                ? List.of()
                : Arrays.stream(p.getWorkoutIds().split(",")).map(Long::valueOf).toList();
        return new ProposalResponse(p.getId(), p.getStatus(), ProposalParser.fromJson(p.getProposalJson()), p.getCreatedAt(), workoutIds);
    }
}
