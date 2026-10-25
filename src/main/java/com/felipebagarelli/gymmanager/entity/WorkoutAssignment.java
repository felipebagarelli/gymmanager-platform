package com.felipebagarelli.gymmanager.entity;

import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "workout_assignments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkoutAssignment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "workout_id", nullable = false)
    private Workout workout;

    @ManyToOne
    @JoinColumn(name = "student_id", nullable = false)
    private StudentProfile student;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WorkoutAssignmentStatus status;

    private LocalDateTime startedAt;
    private LocalDateTime endedAt;

    /** Dias da semana do treino para este aluno (ver {@link Weekdays}); 0 = sem dia marcado. */
    @Builder.Default
    @Column(nullable = false)
    private int weekdays = 0;

    /** Posicao na sequencia do esquema rotativo (1, 2, 3...); null = fora da sequencia. */
    private Integer rotationOrder;
}
