package com.felipebagarelli.gymmanager.entity;


import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "exercises")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Exercises {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String muscleGroup;

    /** Dono do exercicio; null = catalogo comum (ninguem altera pela API). */
    @ManyToOne
    @JoinColumn(name = "trainer_id")
    private TrainerProfile trainer;

    /** Equipamento principal (catalogo; nulo nos exercicios criados pelo personal). */
    @Enumerated(EnumType.STRING)
    private ExerciseEquipment equipment;

    /** Codigo estavel do exercicio do catalogo (a IA se refere ao exercicio por ele). */
    private String catalogCode;

}
