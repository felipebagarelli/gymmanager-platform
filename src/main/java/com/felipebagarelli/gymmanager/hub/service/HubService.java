package com.felipebagarelli.gymmanager.hub.service;

import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.PlanResponse;
import com.felipebagarelli.gymmanager.billing.dto.BillingDtos.UrlResponse;
import com.felipebagarelli.gymmanager.billing.entity.Plan;
import com.felipebagarelli.gymmanager.billing.entity.TrainerPayoutAccount;
import com.felipebagarelli.gymmanager.billing.repository.PlanRepository;
import com.felipebagarelli.gymmanager.billing.repository.TrainerPayoutAccountRepository;
import com.felipebagarelli.gymmanager.billing.service.SubscriptionService;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.PublicProfileRequest;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.PublicProfileResponse;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.TrainerCard;
import com.felipebagarelli.gymmanager.hub.dto.HubDtos.TrainerDetail;
import com.felipebagarelli.gymmanager.hub.entity.TrainerSpecialty;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Period;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Hub de personais (Fase E): perfil publico, busca e contratacao pelo app. A contratacao cria o
 * vinculo como pendente (INVITED); so o pagamento confirmado pelo webhook o torna ativo.
 */
@Service
public class HubService {

    private static final int ADULT_AGE = 18;

    private final TrainerProfileRepository trainerProfileRepository;
    private final PlanRepository planRepository;
    private final TrainerPayoutAccountRepository payoutRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;
    private final SubscriptionService subscriptionService;
    private final Clock clock;

    @Autowired
    public HubService(TrainerProfileRepository trainerProfileRepository, PlanRepository planRepository,
                      TrainerPayoutAccountRepository payoutRepository, StudentProfileRepository studentProfileRepository,
                      TrainerStudentRepository trainerStudentRepository, SubscriptionService subscriptionService) {
        this(trainerProfileRepository, planRepository, payoutRepository, studentProfileRepository,
                trainerStudentRepository, subscriptionService, Clock.systemDefaultZone());
    }

    HubService(TrainerProfileRepository trainerProfileRepository, PlanRepository planRepository,
               TrainerPayoutAccountRepository payoutRepository, StudentProfileRepository studentProfileRepository,
               TrainerStudentRepository trainerStudentRepository, SubscriptionService subscriptionService, Clock clock) {
        this.trainerProfileRepository = trainerProfileRepository;
        this.planRepository = planRepository;
        this.payoutRepository = payoutRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
        this.subscriptionService = subscriptionService;
        this.clock = clock;
    }

    // ------------------------------------------------------------------ personal

    private TrainerProfile trainerOf(String email) {
        return trainerProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
    }

    static List<TrainerSpecialty> specialties(String csv) {
        if (csv == null || csv.isBlank()) return List.of();
        List<TrainerSpecialty> out = new ArrayList<>();
        for (String raw : csv.split(",")) {
            try {
                out.add(TrainerSpecialty.valueOf(raw.trim()));
            } catch (IllegalArgumentException ignored) {
                // especialidade que saiu da lista: ignora
            }
        }
        return out;
    }

    private boolean canReceive(TrainerProfile trainer) {
        return payoutRepository.findByTrainerId(trainer.getId()).map(TrainerPayoutAccount::isChargesEnabled).orElse(false);
    }

    /** O que falta para aparecer na busca (vazio = aparece). */
    private List<String> missing(TrainerProfile trainer) {
        List<String> missing = new ArrayList<>();
        if (!trainer.isListed()) missing.add("Ative \"Aparecer no hub\".");
        if (blank(trainer.getHeadline())) missing.add("Escreva uma chamada curta.");
        if (planRepository.findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(trainer.getId()).isEmpty()) {
            missing.add("Tenha pelo menos um plano ativo.");
        }
        if (!canReceive(trainer)) missing.add("Conclua o cadastro de recebimento no Stripe.");
        if (!trainer.getUser().isActive()) missing.add("Conta inativa.");
        return missing;
    }

    private static boolean blank(String s) {
        return s == null || s.isBlank();
    }

    private static String trimOrNull(String s, int max) {
        if (s == null) return null;
        String t = s.trim().replaceAll("\\s+", " ");
        if (t.isEmpty()) return null;
        return t.length() > max ? t.substring(0, max) : t;
    }

    private PublicProfileResponse toProfile(TrainerProfile t) {
        List<String> missing = missing(t);
        return new PublicProfileResponse(t.isListed(), t.getHeadline(), t.getBio(), t.getCity(), t.getState(),
                t.isOnline(), t.isInPerson(), specialties(t.getSpecialties()), missing.isEmpty(), missing);
    }

    public PublicProfileResponse myPublicProfile(String email) {
        return toProfile(trainerOf(email));
    }

    @Transactional
    public PublicProfileResponse updatePublicProfile(PublicProfileRequest request, String email) {
        TrainerProfile t = trainerOf(email);
        t.setListed(request.listed());
        t.setHeadline(trimOrNull(request.headline(), 120));
        t.setBio(request.bio() == null || request.bio().isBlank() ? null : request.bio().trim());
        t.setCity(trimOrNull(request.city(), 80));
        t.setState(blank(request.state()) ? null : request.state().trim().toUpperCase(Locale.ROOT));
        t.setOnline(request.online());
        t.setInPerson(request.inPerson());
        t.setSpecialties(request.specialties() == null ? null
                : request.specialties().stream().map(Enum::name).sorted().collect(Collectors.joining(",")));
        if (!request.online() && !request.inPerson()) {
            throw new ConflictException("Marque se atende online, presencial ou os dois.");
        }
        return toProfile(trainerProfileRepository.save(t));
    }

    // ------------------------------------------------------------------ aluno

    /** Personais que aparecem: escolheram aparecer, tem chamada, plano ativo e recebimento. */
    private List<TrainerProfile> visibleTrainers() {
        return trainerProfileRepository.findByListedTrueOrderByDisplayNameAsc().stream()
                .filter(t -> missing(t).isEmpty())
                .toList();
    }

    static String fold(String s) {
        if (s == null) return "";
        return Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}", "").toLowerCase(Locale.ROOT);
    }

    public List<TrainerCard> search(String query, TrainerSpecialty specialty, Boolean online, String city) {
        String q = fold(query).trim();
        String c = fold(city).trim();
        List<TrainerCard> out = new ArrayList<>();
        for (TrainerProfile t : visibleTrainers()) {
            List<TrainerSpecialty> specs = specialties(t.getSpecialties());
            if (specialty != null && !specs.contains(specialty)) continue;
            if (Boolean.TRUE.equals(online) && !t.isOnline()) continue;
            if (!c.isEmpty() && !fold(t.getCity()).contains(c)) continue;
            if (!q.isEmpty()) {
                String haystack = fold(String.join(" ", nz(t.getDisplayName()), nz(t.getHeadline()), nz(t.getBio()), nz(t.getCity())));
                if (Arrays.stream(q.split("\\s+")).anyMatch(word -> !haystack.contains(word))) continue;
            }
            int from = planRepository.findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(t.getId()).getFirst().getPriceCents();
            out.add(new TrainerCard(t.getId(), t.getDisplayName(), t.getHeadline(), t.getCity(), t.getState(),
                    t.isOnline(), t.isInPerson(), specs, from));
        }
        return out;
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private TrainerProfile visible(Long trainerId) {
        return trainerProfileRepository.findById(trainerId)
                .filter(t -> missing(t).isEmpty())
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
    }

    public TrainerDetail detail(Long trainerId) {
        TrainerProfile t = visible(trainerId);
        List<PlanResponse> plans = planRepository.findByTrainerIdAndActiveTrueOrderByPriceCentsAsc(t.getId()).stream()
                .map(p -> new PlanResponse(p.getId(), p.getName(), p.getDescription(), p.getPriceCents(), p.isActive()))
                .toList();
        return new TrainerDetail(t.getId(), t.getDisplayName(), t.getHeadline(), t.getBio(), t.getCity(), t.getState(),
                t.isOnline(), t.isInPerson(), specialties(t.getSpecialties()), plans);
    }

    /** O personal pode receber pagamentos (para o convite mostrar se da para assinar agora). */
    public boolean canHire(TrainerProfile trainer) {
        return trainer.getUser().isActive() && canReceive(trainer);
    }

    /**
     * Contratar pelo app: cria (ou reaproveita) o vinculo como pendente e abre o checkout do plano.
     * O vinculo so fica ativo quando o webhook confirmar o pagamento.
     */
    @Transactional
    public UrlResponse hire(Long trainerId, Long planId, String email) {
        StudentProfile student = studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        if (student.getBirthDate() == null || Period.between(student.getBirthDate(), LocalDate.now(clock)).getYears() < ADULT_AGE) {
            throw new ConflictException("Para menores de 18 anos, a contratação depende da aprovação do responsável (em breve).");
        }
        TrainerProfile trainer = visible(trainerId);
        Plan plan = planRepository.findById(planId)
                .filter(p -> p.isActive() && p.getTrainer().getId().equals(trainer.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Plano não encontrado!"));
        return contract(student, trainer, plan, email);
    }

    /**
     * Contratar pelo link de convite do plano: o personal nao precisa aparecer no hub, mas precisa
     * receber pagamentos. Mesmas regras do hub (maior de 18, sem personal ativo).
     */
    @Transactional
    public UrlResponse hireByInvite(Plan plan, String email) {
        StudentProfile student = studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        if (student.getBirthDate() == null || Period.between(student.getBirthDate(), LocalDate.now(clock)).getYears() < ADULT_AGE) {
            throw new ConflictException("Para menores de 18 anos, a contratação depende da aprovação do responsável (em breve).");
        }
        TrainerProfile trainer = plan.getTrainer();
        if (!plan.isActive() || !trainer.getUser().isActive() || !canReceive(trainer)) {
            throw new ConflictException("Este plano não está disponível no momento. Fale com o seu personal.");
        }
        return contract(student, trainer, plan, email);
    }

    private UrlResponse contract(StudentProfile student, TrainerProfile trainer, Plan plan, String email) {
        Optional<TrainerStudent> existing = trainerStudentRepository.findByStudentId(student.getId());
        if (existing.isPresent() && (existing.get().getStatus() == TrainerStudentStatus.ACTIVE
                || existing.get().getStatus() == TrainerStudentStatus.PAUSED)) {
            throw new ConflictException("Você já treina com um personal.");
        }
        TrainerStudent link = existing.orElseGet(() -> TrainerStudent.builder().student(student).createdAt(LocalDateTime.now(clock)).build());
        link.setTrainer(trainer);
        link.setStatus(TrainerStudentStatus.INVITED);
        trainerStudentRepository.save(link);

        return subscriptionService.subscribe(plan.getId(), email);
    }
}
