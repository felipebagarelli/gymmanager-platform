package com.felipebagarelli.gymmanager.aiworkout.service;

import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.AdjustmentChange;
import com.felipebagarelli.gymmanager.aiworkout.dto.ProposalDtos.AdjustmentContent;
import com.felipebagarelli.gymmanager.entity.Exercises;
import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.repository.ExerciseRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutExercisesRepository;
import com.felipebagarelli.gymmanager.session.repository.ExercisePerformanceRepository;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * Aplica um ajuste aceito ao treino. Antes confere que o plano nao mudou desde a proposta. Exercicio
 * trocado que ja tem series registradas so sai do plano (o historico continua apontando para ele).
 */
@Component
public class AdjustmentApplier {

    private static final String CHANGED = "O treino mudou desde a proposta. Gere uma nova.";

    private final WorkoutExercisesRepository planRepository;
    private final ExerciseRepository exerciseRepository;
    private final ExercisePerformanceRepository performanceRepository;

    public AdjustmentApplier(WorkoutExercisesRepository planRepository, ExerciseRepository exerciseRepository,
                             ExercisePerformanceRepository performanceRepository) {
        this.planRepository = planRepository;
        this.exerciseRepository = exerciseRepository;
        this.performanceRepository = performanceRepository;
    }

    public void apply(AdjustmentContent content) {
        // confere tudo antes de mudar qualquer coisa
        for (AdjustmentChange change : content.changes()) {
            WorkoutExercises item = planRepository.findById(change.workoutExerciseId())
                    .filter(i -> i.getRemovedAt() == null && i.getWorkout().getId().equals(content.workoutId()))
                    .orElseThrow(() -> new ConflictException(CHANGED));
            if (item.getSets() != change.setsBefore() || item.getReps() != change.repsBefore()) {
                throw new ConflictException(CHANGED);
            }
        }
        for (AdjustmentChange change : content.changes()) {
            WorkoutExercises item = planRepository.findById(change.workoutExerciseId()).orElseThrow();
            if ("SWAP".equals(change.action())) {
                Exercises replacement = exerciseRepository.findById(change.newExerciseId())
                        .orElseThrow(() -> new ConflictException(CHANGED));
                planRepository.save(WorkoutExercises.builder()
                        .workout(item.getWorkout())
                        .exercise(replacement)
                        .sets(change.setsAfter())
                        .reps(change.repsAfter())
                        .restSeconds(change.restAfter())
                        .position(item.getPosition())
                        .notes(change.note() == null || change.note().isEmpty() ? null : change.note())
                        .build());
                if (performanceRepository.existsByWorkoutExerciseId(item.getId())) {
                    item.setRemovedAt(LocalDateTime.now());
                    planRepository.save(item);
                } else {
                    planRepository.delete(item);
                }
            } else {
                item.setSets(change.setsAfter());
                item.setReps(change.repsAfter());
                item.setRestSeconds(change.restAfter());
                item.setTargetLoad(change.loadAfter());
                if (change.note() != null && !change.note().isEmpty()) item.setNotes(change.note());
                planRepository.save(item);
            }
        }
    }
}
