package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutExerciseRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutExercisesResponse;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class WorkoutExerciseService {

    private final WorkoutExercisesRepository workoutExercisesRepository;
    private final WorkoutRepository workoutRepository;
    private final ExerciseRepository exerciseRepository;
    private final WorkoutAccessService workoutAccessService;
    private final ExercisePerformanceRepository performanceRepository;

    public WorkoutExerciseService(WorkoutExercisesRepository workoutExercisesRepository,
                                  WorkoutRepository workoutRepository,
                                  ExerciseRepository exerciseRepository,
                                  WorkoutAccessService workoutAccessService,
                                  ExercisePerformanceRepository performanceRepository){
        this.workoutRepository = workoutRepository;
        this.exerciseRepository = exerciseRepository;
        this.workoutExercisesRepository = workoutExercisesRepository;
        this.workoutAccessService = workoutAccessService;
        this.performanceRepository = performanceRepository;
    }

    public WorkoutExercisesResponse toResponse(WorkoutExercises workoutExercises){
        return new WorkoutExercisesResponse(
                workoutExercises.getId(),
                workoutExercises.getExercise().getId(),
                workoutExercises.getWorkout().getId(),
                workoutExercises.getReps(),
                workoutExercises.getSets(),
                workoutExercises.getPosition(),
                workoutExercises.getRestSeconds(),
                workoutExercises.getTargetLoad(),
                workoutExercises.getNotes(),
                workoutExercises.getExercise().getName(),
                workoutExercises.getExercise().getMuscleGroup());
    }

    private Workout findWorkout(Long id){
        return workoutRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Treino não encontrado!"));
    }

    private Exercises findExercise(Long id){
        return exerciseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Exercício não encontrado!"));
    }

    /** Exercicio atual do plano (os retirados nao podem mais ser alterados). */
    private WorkoutExercises findWorkoutExercise(Long id){
        return workoutExercisesRepository.findById(id)
                .filter(item -> item.getRemovedAt() == null)
                .orElseThrow(() -> new ResourceNotFoundException("Exercício não encontrado!"));
    }

    /** O personal so monta treinos com o catalogo comum ou com exercicios dele. */
    private Exercises usableExercise(Long exerciseId, Workout workout){
        Exercises exercise = findExercise(exerciseId);
        // treino do aluno: o catalogo comum ou os exercicios do personal que o acompanha
        boolean allowed = exercise.getTrainer() == null
                || (workout.getTrainer() != null && exercise.getTrainer().getId().equals(workout.getTrainer().getId()))
                || (workout.getStudentOwner() != null
                    && workoutAccessService.isCurrentTrainerOf(workout.getStudentOwner().getId(), exercise.getTrainer().getId()));
        if (!allowed) {
            throw new AccessDeniedException("Você não tem permissão para usar este exercício.");
        }
        return exercise;
    }

    private List<WorkoutExercises> currentPlan(Long workoutId){
        return workoutExercisesRepository.findByWorkoutIdAndRemovedAtIsNullOrderByPositionAscIdAsc(workoutId);
    }

    public WorkoutExercisesResponse addWorkoutExercise(CreateWorkoutExerciseRequest request, String authenticatedEmail) {

        Workout workout = findWorkout(request.workoutId());
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        Exercises exercise = usableExercise(request.exerciseId(), workout);

        // sem posicao informada, entra no fim do plano
        Integer position = request.position();
        if (position == null) {
            position = currentPlan(workout.getId()).stream()
                    .map(WorkoutExercises::getPosition)
                    .filter(p -> p != null)
                    .max(Integer::compare)
                    .orElse(0) + 1;
        }

        WorkoutExercises workoutExercise = WorkoutExercises.builder()
                .exercise(exercise)
                .workout(workout)
                .sets(request.sets())
                .reps(request.reps())
                .position(position)
                .restSeconds(request.restSeconds())
                .targetLoad(request.targetLoad())
                .notes(request.notes())
                .build();

        workoutExercisesRepository.save(workoutExercise);

        return toResponse(workoutExercise);
    }


    public List<WorkoutExercisesResponse> allWorkoutExercises(Long workoutId, String authenticatedEmail) {
        Workout workout = findWorkout(workoutId);
        workoutAccessService.assertCanReadWorkout(workout, authenticatedEmail);

        return currentPlan(workoutId).stream()
                .map(this::toResponse)
                .toList();
    }


    /**
     * Retira o exercicio do treino. Se o aluno ja registrou series dele, so marca como retirado
     * (as series continuam no historico); senao apaga de vez.
     */
    @Transactional
    public void deleteById(Long id, String authenticatedEmail) {
        WorkoutExercises workoutExercise = findWorkoutExercise(id);
        workoutAccessService.assertOwnsWorkout(workoutExercise.getWorkout(), authenticatedEmail);
        if (performanceRepository.existsByWorkoutExerciseId(id)) {
            workoutExercise.setRemovedAt(LocalDateTime.now());
            workoutExercisesRepository.save(workoutExercise);
        } else {
            workoutExercisesRepository.delete(workoutExercise);
        }
    }


    public WorkoutExercisesResponse updateById(
            CreateWorkoutExerciseRequest request,
            Long id,
            String authenticatedEmail) {

        WorkoutExercises workoutExercise = findWorkoutExercise(id);
        workoutAccessService.assertOwnsWorkout(workoutExercise.getWorkout(), authenticatedEmail);

        Workout workout = findWorkout(request.workoutId());
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);
        Exercises exercise = usableExercise(request.exerciseId(), workout);

        workoutExercise.setExercise(exercise);
        workoutExercise.setWorkout(workout);
        workoutExercise.setReps(request.reps());
        workoutExercise.setSets(request.sets());
        if (request.position() != null) {
            workoutExercise.setPosition(request.position());
        }
        workoutExercise.setRestSeconds(request.restSeconds());
        workoutExercise.setTargetLoad(request.targetLoad());
        workoutExercise.setNotes(request.notes());

        workoutExercisesRepository.save(workoutExercise);

        return toResponse(workoutExercise);
    }

    /** Reordena o plano inteiro de uma vez: a lista precisa ter exatamente os exercicios atuais. */
    @Transactional
    public List<WorkoutExercisesResponse> reorder(Long workoutId, List<Long> orderedIds, String authenticatedEmail) {
        Workout workout = findWorkout(workoutId);
        workoutAccessService.assertOwnsWorkout(workout, authenticatedEmail);

        Map<Long, WorkoutExercises> byId = currentPlan(workoutId).stream()
                .collect(Collectors.toMap(WorkoutExercises::getId, Function.identity()));
        if (orderedIds.size() != byId.size() || !new HashSet<>(orderedIds).equals(byId.keySet())) {
            throw new BadRequestException("A nova ordem precisa conter todos os exercícios do treino, uma vez cada.");
        }
        for (int i = 0; i < orderedIds.size(); i++) {
            byId.get(orderedIds.get(i)).setPosition(i + 1);
        }
        workoutExercisesRepository.saveAll(byId.values());
        return currentPlan(workoutId).stream().map(this::toResponse).toList();
    }

    public WorkoutExercisesResponse getById(Long id, String authenticatedEmail){
        WorkoutExercises workoutExercise = workoutExercisesRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Exercício não encontrado!"));
        workoutAccessService.assertCanReadWorkout(workoutExercise.getWorkout(), authenticatedEmail);
        return toResponse(workoutExercise);
    }

}
