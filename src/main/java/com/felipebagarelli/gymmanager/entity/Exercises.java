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

}
