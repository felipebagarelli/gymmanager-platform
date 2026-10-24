package com.felipebagarelli.gymmanager.onboarding.service;

import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.HealthScreeningResponse;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.OnboardingResponse;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainingProfileRequest;
import com.felipebagarelli.gymmanager.onboarding.dto.OnboardingDtos.TrainingProfileResponse;
import com.felipebagarelli.gymmanager.onboarding.entity.Equipment;
import com.felipebagarelli.gymmanager.onboarding.entity.HealthScreening;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingGoal;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLevel;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingLocation;
import com.felipebagarelli.gymmanager.onboarding.entity.TrainingProfile;
import com.felipebagarelli.gymmanager.onboarding.repository.HealthScreeningRepository;
import com.felipebagarelli.gymmanager.onboarding.repository.TrainingProfileRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class OnboardingServiceTest {

    private static final String EMAIL = "maria@example.com";

    private final StudentProfile student = StudentProfile.builder().id(2L).name("Maria").build();
    private final List<TrainingProfile> profiles = new ArrayList<>();
    private final List<HealthScreening> screenings = new ArrayList<>();
    private OnboardingService service;

    @BeforeEach
    void setUp() {
        StudentProfileRepository students = mock(StudentProfileRepository.class);
        when(students.findByUserEmail(EMAIL)).thenReturn(Optional.of(student));
        TrainingProfileRepository profileRepository = mock(TrainingProfileRepository.class);
        when(profileRepository.findByStudentId(anyLong())).thenAnswer(i -> profiles.stream().findFirst());
        when(profileRepository.save(any(TrainingProfile.class))).thenAnswer(i -> {
            TrainingProfile p = i.getArgument(0);
            if (!profiles.contains(p)) profiles.add(p);
            return p;
        });
        HealthScreeningRepository screeningRepository = mock(HealthScreeningRepository.class);
        when(screeningRepository.findFirstByStudentIdOrderByAnsweredAtDescIdDesc(anyLong()))
                .thenAnswer(i -> screenings.isEmpty() ? Optional.empty() : Optional.of(screenings.getLast()));
        when(screeningRepository.save(any(HealthScreening.class))).thenAnswer(i -> {
            screenings.add(i.getArgument(0));
            return i.getArgument(0);
        });
        service = new OnboardingService(students, profileRepository, screeningRepository);
    }

    private static List<Boolean> answers(boolean... values) {
        List<Boolean> list = new ArrayList<>();
        for (boolean v : values) list.add(v);
        return list;
    }

    @Test
    void newStudent_hasNothingYet() {
        OnboardingResponse status = service.status(EMAIL);
        assertThat(status.completed()).isFalse();
        assertThat(status.aiWorkoutsAllowed()).isFalse();
        assertThat(status.trainingProfile()).isNull();
    }

    @Test
    void trainingProfile_savesAndUpdatesHeightAndWeight_equipmentOnlyAtHome() {
        TrainingProfileResponse home = service.saveTrainingProfile(new TrainingProfileRequest(TrainingGoal.HYPERTROPHY,
                TrainingLevel.BEGINNER, 3, 45, TrainingLocation.HOME, Set.of(Equipment.DUMBBELLS, Equipment.BANDS), 1.65, 62.0), EMAIL);
        assertThat(home.equipment()).containsExactly(Equipment.DUMBBELLS, Equipment.BANDS);
        assertThat(student.getWeight()).isEqualTo(62.0);
        assertThat(student.getHeight()).isEqualTo(1.65);

        // academia: equipamento nao e guardado; editar atualiza o mesmo registro
        TrainingProfileResponse gym = service.saveTrainingProfile(new TrainingProfileRequest(TrainingGoal.STRENGTH,
                TrainingLevel.INTERMEDIATE, 4, 60, TrainingLocation.GYM, Set.of(Equipment.DUMBBELLS), null, null), EMAIL);
        assertThat(gym.equipment()).isEmpty();
        assertThat(profiles).hasSize(1);
        assertThat(student.getWeight()).isEqualTo(62.0);
    }

    @Test
    void trainingProfile_homeNeedsEquipment() {
        assertThatThrownBy(() -> service.saveTrainingProfile(new TrainingProfileRequest(TrainingGoal.HEALTH,
                TrainingLevel.BEGINNER, 2, 30, TrainingLocation.HOME, Set.of(), null, null), EMAIL))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void screening_anyYesMeansRisk_andBlocksAiWorkouts() {
        service.saveTrainingProfile(new TrainingProfileRequest(TrainingGoal.HEALTH, TrainingLevel.BEGINNER, 2, 30,
                TrainingLocation.BODYWEIGHT, null, null, null), EMAIL);

        HealthScreeningResponse risky = service.answerScreening(answers(false, false, true, false, false, false, false), EMAIL);
        assertThat(risky.risk()).isTrue();
        assertThat(screenings.getLast().getAnswers()).isEqualTo("NNSNNNN");
        OnboardingResponse status = service.status(EMAIL);
        assertThat(status.completed()).isTrue();
        assertThat(status.aiWorkoutsAllowed()).isFalse();

        // respondeu de novo (ex.: liberado pelo medico): vale a mais recente; o historico fica
        service.answerScreening(answers(false, false, false, false, false, false, false), EMAIL);
        assertThat(service.status(EMAIL).aiWorkoutsAllowed()).isTrue();
        assertThat(screenings).hasSize(2);
    }

    @Test
    void screening_needsEveryAnswer() {
        assertThatThrownBy(() -> service.answerScreening(answers(false, false), EMAIL)).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> service.answerScreening(Arrays.asList(false, false, null, false, false, false, false), EMAIL))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void screeningOlderThan12Months_blocksAiUntilAnsweredAgain() {
        screenings.add(HealthScreening.builder().id(1L).student(student).answers("NNNNNNN").risk(false)
                .answeredAt(java.time.LocalDateTime.now().minusDays(400)).build());
        OnboardingResponse old = service.status(EMAIL);
        assertThat(old.screeningExpired()).isTrue();
        assertThat(old.aiWorkoutsAllowed()).isFalse();

        service.answerScreening(answers(false, false, false, false, false, false, false), EMAIL);
        OnboardingResponse fresh = service.status(EMAIL);
        assertThat(fresh.screeningExpired()).isFalse();
    }

    @Test
    void sharingWithTrainer_isTheStudentsChoice() {
        assertThat(service.status(EMAIL).shareWithTrainer()).isFalse();
        assertThat(service.setSharing(true, EMAIL).shareWithTrainer()).isTrue();
        assertThat(service.setSharing(false, EMAIL).shareWithTrainer()).isFalse();
    }
}
