package com.felipebagarelli.gymmanager.entity;


import jakarta.persistence.*;
import lombok.*;

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

}