package com.felipebagarelli.gymmanager.service;


import com.felipebagarelli.gymmanager.dto.request.CreateExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.ExerciseResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Biblioteca de exercicios. Ha o catalogo comum (sem dono, somente leitura) e os exercicios
 * de cada personal: so o dono altera ou exclui; os alunos dele enxergam para ver o plano.
 */
@Service
public class ExerciseService {

    private static final String NOT_FOUND = "Exercício não encontrado!";

    private final ExerciseRepository exerciseRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;
    private final WorkoutExercisesRepository workoutExercisesRepository;

    public ExerciseService(ExerciseRepository exerciseRepository,
                           TrainerProfileRepository trainerProfileRepository,
                           StudentProfileRepository studentProfileRepository,
                           TrainerStudentRepository trainerStudentRepository,
                           WorkoutExercisesRepository workoutExercisesRepository){
        this.exerciseRepository = exerciseRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
    }

    private ExerciseResponse toResponse (Exercises exercise){
        Long trainerId = exercise.getTrainer() != null ? exercise.getTrainer().getId() : null;
        return new ExerciseResponse(exercise.getId(), exercise.getName(), exercise.getMuscleGroup(), trainerId);
    }

    private Exercises findExercise(Long id){
        return exerciseRepository.findById(id).orElseThrow(() -> new ResourceNotFoundException(NOT_FOUND));
    }

    /** Personal cuja biblioteca o usuario enxerga: o proprio (personal) ou o do vinculo (aluno). */
    private Optional<Long> libraryTrainerId(String authenticatedEmail){
        Optional<TrainerProfile> trainer = trainerProfileRepository.findByUserEmail(authenticatedEmail);
        if (trainer.isPresent()) {
            return trainer.map(TrainerProfile::getId);
        }
        return studentProfileRepository.findByUserEmail(authenticatedEmail)
                .flatMap(student -> trainerStudentRepository.findByStudentId(student.getId()))
                .map(TrainerStudent::getTrainer)
                .map(TrainerProfile::getId);
    }

    private void assertOwns(Exercises exercise, String authenticatedEmail){
        boolean owner = exercise.getTrainer() != null
                && exercise.getTrainer().getUser().getEmail().equalsIgnoreCase(authenticatedEmail);
        if (!owner) {
            throw new AccessDeniedException(exercise.getTrainer() == null
                    ? "Exercícios do catálogo não podem ser alterados. Crie um exercício seu."
                    : "Você não tem permissão para alterar este exercício.");
        }
    }

    public ExerciseResponse addExercise(CreateExerciseRequest request, String authenticatedEmail) {
        TrainerProfile trainer = trainerProfileRepository.findByUserEmail(authenticatedEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
        Exercises exercise = Exercises.builder()
                .name(request.name().trim())
                .muscleGroup(request.muscleGroup().trim())
                .trainer(trainer)
                .build();
        exerciseRepository.save(exercise);

        return toResponse(exercise);
    }

    public List<ExerciseResponse> allExercises (String authenticatedEmail){
        List<Exercises> listExercises = libraryTrainerId(authenticatedEmail)
                .map(exerciseRepository::findByTrainerIsNullOrTrainerIdOrderByNameAsc)
                .orElseGet(exerciseRepository::findByTrainerIsNullOrderByNameAsc);
        return listExercises.stream().map(this::toResponse).toList();
    }

    public ExerciseResponse getExercisesById(Long id, String authenticatedEmail){
        Exercises exercise = findExercise(id);
        if (exercise.getTrainer() != null
                && !libraryTrainerId(authenticatedEmail).map(exercise.getTrainer().getId()::equals).orElse(false)) {
            throw new ResourceNotFoundException(NOT_FOUND);
        }
        return toResponse(exercise);
    }

    public void deleteById (Long id, String authenticatedEmail){
        Exercises exercise = findExercise(id);
        assertOwns(exercise, authenticatedEmail);
        if (workoutExercisesRepository.existsByExerciseId(id)) {
            throw new ConflictException("Este exercício está em um treino (ou no histórico de algum aluno) e não pode ser excluído.");
        }
        exerciseRepository.delete(exercise);
    }

    public ExerciseResponse updateById(CreateExerciseRequest request, Long id, String authenticatedEmail){
        Exercises exercise = findExercise(id);
        assertOwns(exercise, authenticatedEmail);
        exercise.setName(request.name().trim());
        exercise.setMuscleGroup(request.muscleGroup().trim());
        exerciseRepository.save(exercise);
        return toResponse(exercise);
    }


}
