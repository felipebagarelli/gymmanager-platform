package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.billing.service.BillingAccessGuard;
import com.felipebagarelli.gymmanager.dto.RoutineDtos.RoutineResponse;
import com.felipebagarelli.gymmanager.entity.RoutineMode;
import com.felipebagarelli.gymmanager.entity.StudentRoutine;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.repository.StudentRoutineRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** F3: esquema rotativo (AB, ABC...). */
class RoutineServiceTest {

    private static final String JOAO = "joao@example.com";
    private static final String ANA = "ana@example.com";

    private final List<WorkoutAssignment> assignments = new ArrayList<>();
    private final List<WorkoutSession> sessions = new ArrayList<>();
    private final Map<Long, StudentRoutine> routines = new HashMap<>();
    private final Map<Long, Workout> workouts = new HashMap<>();
    private final AtomicLong ids = new AtomicLong(100);
    private TrainerStudentRepository links;
    private StudentProfile ana;
    private StudentProfile bia;
    private TrainerProfile joao;
    private RoutineService service;

    @BeforeEach
    void setUp() {
        joao = TrainerProfile.builder().id(1L).user(User.builder().email(JOAO).role(Role.TRAINER).build()).build();
        ana = StudentProfile.builder().id(2L).name("Ana").user(User.builder().email(ANA).role(Role.STUDENT).build()).build();
        bia = StudentProfile.builder().id(3L).name("Bia").user(User.builder().email("bia@example.com").role(Role.STUDENT).build()).build();

        links = mock(TrainerStudentRepository.class);
        when(links.findByStudentId(2L)).thenReturn(Optional.of(link(ana)));
        when(links.findByStudentId(3L)).thenReturn(Optional.of(link(bia)));
        StudentProfileRepository students = mock(StudentProfileRepository.class);
        when(students.findById(2L)).thenReturn(Optional.of(ana));
        when(students.findById(3L)).thenReturn(Optional.of(bia));

        WorkoutAssignmentRepository assignmentRepository = mock(WorkoutAssignmentRepository.class);
        when(assignmentRepository.findByStudentIdAndStatus(anyLong(), any())).thenAnswer(i -> assignments.stream()
                .filter(a -> a.getStudent().getId().equals(i.getArgument(0)) && a.getStatus() == i.getArgument(1)).toList());
        when(assignmentRepository.save(any(WorkoutAssignment.class))).thenAnswer(i -> {
            WorkoutAssignment a = i.getArgument(0);
            if (a.getId() == null) a.setId(ids.getAndIncrement());
            if (!assignments.contains(a)) assignments.add(a);
            return a;
        });
        WorkoutRepository workoutRepository = mock(WorkoutRepository.class);
        when(workoutRepository.findById(anyLong())).thenAnswer(i -> Optional.ofNullable(workouts.get((Long) i.getArgument(0))));
        WorkoutSessionRepository sessionRepository = mock(WorkoutSessionRepository.class);
        when(sessionRepository.findByAssignmentStudentIdOrderByStartedAtDesc(anyLong())).thenAnswer(i -> sessions.stream()
                .filter(s -> s.getAssignment().getStudent().getId().equals(i.getArgument(0)))
                .sorted((a, b) -> b.getStartedAt().compareTo(a.getStartedAt())).toList());
        StudentRoutineRepository routineRepository = mock(StudentRoutineRepository.class);
        when(routineRepository.findById(anyLong())).thenAnswer(i -> Optional.ofNullable(routines.get((Long) i.getArgument(0))));
        when(routineRepository.save(any(StudentRoutine.class))).thenAnswer(i -> {
            StudentRoutine r = i.getArgument(0);
            routines.put(r.getStudentId(), r);
            return r;
        });

        WorkoutAccessService access = new WorkoutAccessService(links, students, assignmentRepository, mock(BillingAccessGuard.class));
        service = new RoutineService(routineRepository, assignmentRepository, workoutRepository, sessionRepository, students, access);
    }

    private TrainerStudent link(StudentProfile student) {
        return TrainerStudent.builder().trainer(joao).student(student).status(TrainerStudentStatus.ACTIVE).build();
    }

    private Workout workout(long id, String name, boolean ownedByAna) {
        Workout w = ownedByAna
                ? Workout.builder().id(id).name(name).studentOwner(ana).build()
                : Workout.builder().id(id).name(name).trainer(joao).build();
        workouts.put(id, w);
        return w;
    }

    private WorkoutAssignment assign(Workout w, StudentProfile s) {
        WorkoutAssignment a = WorkoutAssignment.builder().id(ids.getAndIncrement()).workout(w).student(s)
                .status(WorkoutAssignmentStatus.ACTIVE).startedAt(LocalDateTime.now()).build();
        assignments.add(a);
        return a;
    }

    private void finish(WorkoutAssignment a, LocalDateTime when) {
        sessions.add(WorkoutSession.builder().id(ids.getAndIncrement()).assignment(a).startedAt(when).finishedAt(when.plusMinutes(50)).build());
    }

    @Test
    void sequence_followsTheLastFinishedWorkout_notTheDay() {
        WorkoutAssignment a = assign(workout(10, "A", false), ana);
        WorkoutAssignment b = assign(workout(11, "B", false), ana);
        WorkoutAssignment c = assign(workout(12, "C", false), ana);

        RoutineResponse start = service.set(2L, RoutineMode.ROTATION, List.of(10L, 11L, 12L), JOAO);
        assertThat(start.sequence()).extracting(i -> i.workoutId()).containsExactly(10L, 11L, 12L);
        assertThat(start.nextWorkoutId()).isEqualTo(10L);

        finish(a, LocalDateTime.now().minusDays(3));
        assertThat(service.get(2L, ANA).nextWorkoutId()).isEqualTo(11L);
        finish(b, LocalDateTime.now().minusDays(1));
        assertThat(service.get(2L, ANA).nextWorkoutId()).isEqualTo(12L);
        finish(c, LocalDateTime.now().minusHours(2));
        assertThat(service.get(2L, ANA).nextWorkoutId()).isEqualTo(10L); // volta ao comeco
    }

    @Test
    void skip_choosesTheNextUntilTheNextFinishedSession() {
        WorkoutAssignment a = assign(workout(10, "A", false), ana);
        assign(workout(11, "B", false), ana);
        WorkoutAssignment c = assign(workout(12, "C", false), ana);
        service.set(2L, RoutineMode.ROTATION, List.of(10L, 11L, 12L), JOAO);
        finish(a, LocalDateTime.now().minusDays(1));

        assertThat(service.skipTo(2L, 12L, ANA).nextWorkoutId()).isEqualTo(12L); // o proprio aluno pula o B
        finish(c, LocalDateTime.now().plusMinutes(1));
        assertThat(service.get(2L, ANA).nextWorkoutId()).isEqualTo(10L);

        assertThatThrownBy(() -> service.skipTo(2L, 99L, ANA)).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> service.skipTo(2L, 10L, "outro@example.com")).isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void weekdaysMode_hasNoNext_andSkipIsRefused() {
        assign(workout(10, "A", false), ana);
        assign(workout(11, "B", false), ana);
        assertThat(service.get(2L, JOAO).mode()).isEqualTo(RoutineMode.WEEKDAYS);

        service.set(2L, RoutineMode.ROTATION, List.of(10L, 11L), JOAO);
        service.useWeekdays(2L);
        RoutineResponse back = service.get(2L, JOAO);
        assertThat(back.mode()).isEqualTo(RoutineMode.WEEKDAYS);
        assertThat(back.nextWorkoutId()).isNull();
        assertThatThrownBy(() -> service.skipTo(2L, 10L, ANA)).isInstanceOf(ConflictException.class);
    }

    @Test
    void rules_twoOrMoreActiveWorkouts_onlyTheTrainerOrTheIndependentStudent() {
        assign(workout(10, "A", false), ana);
        assign(workout(11, "B", false), ana);

        assertThatThrownBy(() -> service.set(2L, RoutineMode.ROTATION, List.of(10L), JOAO)).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> service.set(2L, RoutineMode.ROTATION, List.of(10L, 77L), JOAO)).isInstanceOf(BadRequestException.class);
        // aluna com personal nao muda o esquema; outro personal tambem nao
        assertThatThrownBy(() -> service.set(2L, RoutineMode.ROTATION, List.of(10L, 11L), ANA)).isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> service.set(2L, RoutineMode.ROTATION, List.of(10L, 11L), "outro@example.com"))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void independentStudent_buildsTheSequenceWithOwnWorkoutsOnly() {
        when(links.findByStudentId(2L)).thenReturn(Optional.empty());
        assign(workout(20, "Superiores", true), ana);
        assign(workout(21, "Inferiores", true), ana);

        RoutineResponse own = service.set(2L, RoutineMode.ROTATION, List.of(21L, 20L), ANA);
        assertThat(own.nextWorkoutId()).isEqualTo(21L);

        assign(workout(10, "Do personal antigo", false), ana);
        assertThatThrownBy(() -> service.set(2L, RoutineMode.ROTATION, List.of(20L, 10L), ANA))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void applyToStudents_assignsWhatIsMissing_andSetsTheSameSequence() {
        workout(10, "A", false);
        workout(11, "B", false);
        assign(workouts.get(10L), ana); // a Ana ja tem o A

        List<RoutineResponse> result = service.applyToStudents(List.of(2L, 3L), List.of(10L, 11L), JOAO);

        assertThat(result).allSatisfy(r -> assertThat(r.sequence()).extracting(i -> i.workoutId()).containsExactly(10L, 11L));
        assertThat(assignments).filteredOn(a -> a.getStudent() == ana).hasSize(2);
        assertThat(assignments).filteredOn(a -> a.getStudent() == bia).hasSize(2);

        workout(20, "Da Ana", true);
        assertThatThrownBy(() -> service.applyToStudents(List.of(3L), List.of(10L, 20L), JOAO)).isInstanceOf(ConflictException.class);
    }
}
