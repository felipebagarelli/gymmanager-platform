package com.felipebagarelli.gymmanager.entity;


import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "WorkoutExercises")
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Getter
@Setter
public class WorkoutExercises {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne
    private Exercises exercise;
    @ManyToOne
    private Workout workout;
    private int sets;
    private int reps;
    private Integer position;
    private Integer restSeconds;
    private Double targetLoad;
    private String notes;

    /** Retirado do treino depois de ja ter series registradas (some do plano, o historico continua). */
    private LocalDateTime removedAt;

}
