package com.felipebagarelli.gymmanager.session.entity;

import com.felipebagarelli.gymmanager.entity.WorkoutExercises;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "exercise_performances")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExercisePerformance {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "session_id", nullable = false)
    private WorkoutSession session;

    @ManyToOne
    @JoinColumn(name = "workout_exercise_id", nullable = false)
    private WorkoutExercises workoutExercise;

    private int setNumber;
    private int reps;
    private Double loadKg;

    /** Opcional: como o aluno achou a série. */
    @Enumerated(EnumType.STRING)
    private Effort effort;
}
