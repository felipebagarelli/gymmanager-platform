package com.felipebagarelli.gymmanager.entity;


import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import jakarta.persistence.*;
import lombok.*;

@Entity
@NoArgsConstructor
@AllArgsConstructor
@Getter
@Setter
@Table(name = "workout")
@Builder
public class Workout {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    @ManyToOne
    @JoinColumn(name = "trainer_id")
    private TrainerProfile trainer;
}
