package com.felipebagarelli.gymmanager.entity;


import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
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

    /** Treino montado pelo proprio aluno sem personal (trainer fica nulo). */
    @ManyToOne
    @JoinColumn(name = "student_owner_id")
    private StudentProfile studentOwner;
}
