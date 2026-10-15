package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.dto.request.CreateExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.ExerciseResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.access.AccessDeniedException;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ExerciseServiceTest {

    @Mock private ExerciseRepository exerciseRepository;
    @Mock private TrainerProfileRepository trainerProfileRepository;
    @Mock private StudentProfileRepository studentProfileRepository;
    @Mock private TrainerStudentRepository trainerStudentRepository;
    @Mock private WorkoutExercisesRepository workoutExercisesRepository;

    @InjectMocks private ExerciseService service;

    private TrainerProfile trainer;
    private Exercises catalog;
    private Exercises mine;
    private Exercises others;

    @BeforeEach
    void setUp() {
        trainer = TrainerProfile.builder().id(1L)
                .user(User.builder().email("joao@example.com").role(Role.TRAINER).build()).build();
        TrainerProfile other = TrainerProfile.builder().id(9L)
                .user(User.builder().email("outro@example.com").role(Role.TRAINER).build()).build();
        catalog = Exercises.builder().id(1L).name("Supino").muscleGroup("Peito").build();
        mine = Exercises.builder().id(2L).name("Supino com pausa").muscleGroup("Peito").trainer(trainer).build();
        others = Exercises.builder().id(3L).name("Remada secreta").muscleGroup("Costas").trainer(other).build();

        lenient().when(trainerProfileRepository.findByUserEmail("joao@example.com")).thenReturn(Optional.of(trainer));
        lenient().when(trainerProfileRepository.findByUserEmail("aluno@example.com")).thenReturn(Optional.empty());
        lenient().when(exerciseRepository.findById(1L)).thenReturn(Optional.of(catalog));
        lenient().when(exerciseRepository.findById(2L)).thenReturn(Optional.of(mine));
        lenient().when(exerciseRepository.findById(3L)).thenReturn(Optional.of(others));
    }

    @Test
    void addExercise_belongsToTheTrainer() {
        ExerciseResponse created = service.addExercise(new CreateExerciseRequest("  Agachamento búlgaro ", "Pernas"), "joao@example.com");

        ArgumentCaptor<Exercises> saved = ArgumentCaptor.forClass(Exercises.class);
        verify(exerciseRepository).save(saved.capture());
        assertThat(saved.getValue().getTrainer()).isSameAs(trainer);
        assertThat(created.name()).isEqualTo("Agachamento búlgaro");
        assertThat(created.trainerId()).isEqualTo(1L);
    }

    @Test
    void allExercises_trainerSeesCatalogPlusOwn() {
        when(exerciseRepository.findByTrainerIsNullOrTrainerIdOrderByNameAsc(1L)).thenReturn(List.of(catalog, mine));

        assertThat(service.allExercises("joao@example.com")).extracting(ExerciseResponse::id).containsExactly(1L, 2L);
    }

    @Test
    void allExercises_studentSeesCatalogPlusTheirTrainers() {
        StudentProfile student = StudentProfile.builder().id(5L).build();
        when(studentProfileRepository.findByUserEmail("aluno@example.com")).thenReturn(Optional.of(student));
        when(trainerStudentRepository.findByStudentId(5L))
                .thenReturn(Optional.of(TrainerStudent.builder().trainer(trainer).student(student).build()));
        when(exerciseRepository.findByTrainerIsNullOrTrainerIdOrderByNameAsc(1L)).thenReturn(List.of(catalog, mine));

        assertThat(service.allExercises("aluno@example.com")).hasSize(2);
    }

    @Test
    void getById_hidesAnotherTrainersExercise() {
        assertThatThrownBy(() -> service.getExercisesById(3L, "joao@example.com"))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThat(service.getExercisesById(1L, "joao@example.com").name()).isEqualTo("Supino");
    }

    @Test
    void updateAndDelete_onlyTheOwner() {
        CreateExerciseRequest request = new CreateExerciseRequest("Novo", "Peito");
        assertThatThrownBy(() -> service.updateById(request, 1L, "joao@example.com"))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("catálogo");
        assertThatThrownBy(() -> service.updateById(request, 3L, "joao@example.com"))
                .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> service.deleteById(3L, "joao@example.com"))
                .isInstanceOf(AccessDeniedException.class);
        verify(exerciseRepository, never()).delete(any());

        assertThat(service.updateById(request, 2L, "joao@example.com").name()).isEqualTo("Novo");
    }

    @Test
    void delete_blockedWhenUsedInAWorkout() {
        when(workoutExercisesRepository.existsByExerciseId(2L)).thenReturn(true);

        assertThatThrownBy(() -> service.deleteById(2L, "joao@example.com")).isInstanceOf(ConflictException.class);
        verify(exerciseRepository, never()).delete(any());
    }

    @Test
    void delete_ownUnusedExercise() {
        when(workoutExercisesRepository.existsByExerciseId(2L)).thenReturn(false);

        service.deleteById(2L, "joao@example.com");
        verify(exerciseRepository).delete(mine);
    }
}
