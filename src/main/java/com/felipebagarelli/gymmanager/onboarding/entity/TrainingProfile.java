package com.felipebagarelli.gymmanager.onboarding.entity;

import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Preferencias de treino do aluno (onboarding): base para a IA montar treinos (Fase D). */
@Entity
@Table(name = "student_training_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainingProfile {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "student_id", nullable = false, unique = true)
    private StudentProfile student;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TrainingGoal goal;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TrainingLevel level;

    private int daysPerWeek;
    private int minutesPerSession;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TrainingLocation location;

    /** Equipamentos separados por virgula (so quando treina em casa). */
    private String equipment;

    @Column(nullable = false)
    private LocalDateTime updatedAt;
}
