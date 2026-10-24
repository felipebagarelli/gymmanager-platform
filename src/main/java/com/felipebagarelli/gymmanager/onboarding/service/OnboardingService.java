package com.felipebagarelli.gymmanager.onboarding.service;

import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.HealthScreeningResponse;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.OnboardingResponse;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainingProfileRequest;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainingProfileResponse;
import com.felipebagarelli.gymmanager.onboarding.entity.Equipment;
import com.felipebagarelli.gymmanager.onboarding.entity.HealthScreening;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLocation;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import com.felipebagarelli.gymmanager.onboarding.repository.HealthScreeningRepository;
import com.felipebagarelli.gymmanager.onboarding.repository.TrainingProfileRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Onboarding do aluno (preferencias de treino) e triagem de saude. Qualquer "sim" na triagem
 * marca risco: o app recomenda avaliacao medica/profissional e a IA nao gera treino (Fase D).
 */
@Service
public class OnboardingService {

    /** Versao das perguntas da triagem (o app mostra as perguntas desta versao, na mesma ordem). */
    public static final String SCREENING_VERSION = "triagem-2026-10";
    public static final int SCREENING_QUESTIONS = 7;
    /** Triagem vale 12 meses: depois, o app pede para responder de novo (boa pratica, nao exigencia legal). */
    public static final java.time.Duration SCREENING_VALIDITY = java.time.Duration.ofDays(365);

    public static boolean expired(HealthScreening screening) {
        return screening.getAnsweredAt() != null && screening.getAnsweredAt().plus(SCREENING_VALIDITY).isBefore(LocalDateTime.now());
    }

    private final StudentProfileRepository studentProfileRepository;
    private final TrainingProfileRepository trainingProfileRepository;
    private final HealthScreeningRepository screeningRepository;

    public OnboardingService(StudentProfileRepository studentProfileRepository,
                             TrainingProfileRepository trainingProfileRepository,
                             HealthScreeningRepository screeningRepository) {
        this.studentProfileRepository = studentProfileRepository;
        this.trainingProfileRepository = trainingProfileRepository;
        this.screeningRepository = screeningRepository;
    }

    private StudentProfile studentOf(String email) {
        return studentProfileRepository.findByUserEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
    }

    private static List<Equipment> parse(String csv) {
        if (csv == null || csv.isBlank()) return List.of();
        return Arrays.stream(csv.split(",")).map(String::trim).map(Equipment::valueOf).sorted().toList();
    }

    private static TrainingProfileResponse toResponse(TrainingProfile p) {
        StudentProfile s = p.getStudent();
        return new TrainingProfileResponse(p.getGoal(), p.getLevel(), p.getDaysPerWeek(), p.getMinutesPerSession(),
                p.getLocation(), parse(p.getEquipment()), s.getHeight(), s.getWeight(), p.getUpdatedAt());
    }

    private static HealthScreeningResponse toResponse(HealthScreening h) {
        return new HealthScreeningResponse(h.getVersion(), h.isRisk(), h.getAnsweredAt());
    }

    public OnboardingResponse status(String email) {
        StudentProfile student = studentOf(email);
        Optional<TrainingProfile> profile = trainingProfileRepository.findByStudentId(student.getId());
        Optional<HealthScreening> screening = screeningRepository.findFirstByStudentIdOrderByAnsweredAtDescIdDesc(student.getId());
        boolean completed = profile.isPresent() && screening.isPresent();
        boolean isExpired = screening.map(OnboardingService::expired).orElse(false);
        return new OnboardingResponse(
                profile.map(OnboardingService::toResponse).orElse(null),
                screening.map(OnboardingService::toResponse).orElse(null),
                completed,
                screening.map(h -> !h.isRisk() && !expired(h)).orElse(false),
                isExpired,
                student.isShareHealthWithTrainer());
    }

    @Transactional
    public TrainingProfileResponse saveTrainingProfile(TrainingProfileRequest request, String email) {
        StudentProfile student = studentOf(email);
        // equipamento so faz sentido em casa: academia tem tudo, peso do corpo nao usa nenhum
        String equipment = request.location() == TrainingLocation.HOME && request.equipment() != null
                ? request.equipment().stream().map(Enum::name).sorted().collect(Collectors.joining(","))
                : null;
        if (request.location() == TrainingLocation.HOME && (equipment == null || equipment.isEmpty())) {
            throw new BadRequestException("Marque o equipamento que você tem em casa (ou escolha \"só o peso do corpo\").");
        }
        TrainingProfile profile = trainingProfileRepository.findByStudentId(student.getId())
                .orElseGet(() -> TrainingProfile.builder().student(student).build());
        profile.setGoal(request.goal());
        profile.setLevel(request.level());
        profile.setDaysPerWeek(request.daysPerWeek());
        profile.setMinutesPerSession(request.minutesPerSession());
        profile.setLocation(request.location());
        profile.setEquipment(equipment);
        profile.setUpdatedAt(LocalDateTime.now());
        if (request.height() != null) student.setHeight(request.height());
        if (request.weight() != null) student.setWeight(request.weight());
        studentProfileRepository.save(student);
        return toResponse(trainingProfileRepository.save(profile));
    }

    @Transactional
    public HealthScreeningResponse answerScreening(List<Boolean> answers, String email) {
        if (answers.size() != SCREENING_QUESTIONS || answers.contains(null)) {
            throw new BadRequestException("Responda todas as perguntas da triagem.");
        }
        StudentProfile student = studentOf(email);
        String encoded = answers.stream().map(a -> a ? "S" : "N").collect(Collectors.joining());
        HealthScreening saved = screeningRepository.save(HealthScreening.builder()
                .student(student)
                .version(SCREENING_VERSION)
                .answers(encoded)
                .risk(answers.contains(Boolean.TRUE))
                .answeredAt(LocalDateTime.now())
                .build());
        return toResponse(saved);
    }

    @Transactional
    public OnboardingResponse setSharing(boolean share, String email) {
        StudentProfile student = studentOf(email);
        student.setShareHealthWithTrainer(share);
        studentProfileRepository.save(student);
        return status(email);
    }

    /** O personal ve a triagem e o perfil de treino do aluno so se o aluno autorizou. */
    public com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainerHealthView forTrainer(
            Long studentId, String trainerEmail,
            com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository links) {
        var link = links.findByStudentId(studentId)
                .filter(l -> l.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.ACTIVE
                        || l.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.PAUSED)
                .filter(l -> l.getTrainer().getUser().getEmail().equalsIgnoreCase(trainerEmail))
                .orElseThrow(() -> new org.springframework.security.access.AccessDeniedException("Você não acompanha este aluno."));
        StudentProfile student = link.getStudent();
        if (!student.isShareHealthWithTrainer()) {
            return new com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainerHealthView(false, null, null, null, null, List.of());
        }
        TrainingProfileResponse profile = trainingProfileRepository.findByStudentId(student.getId()).map(OnboardingService::toResponse).orElse(null);
        Optional<HealthScreening> screening = screeningRepository.findFirstByStudentIdOrderByAnsweredAtDescIdDesc(student.getId());
        return new com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainerHealthView(true, profile,
                screening.map(HealthScreening::getVersion).orElse(null),
                screening.map(HealthScreening::isRisk).orElse(null),
                screening.map(HealthScreening::getAnsweredAt).orElse(null),
                screening.map(h -> h.getAnswers().chars().mapToObj(c -> c == 'S').toList()).orElse(List.of()));
    }
}
