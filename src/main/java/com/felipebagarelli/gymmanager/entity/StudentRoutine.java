package com.felipebagarelli.gymmanager.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Esquema de treino do aluno. Sem registro = dias da semana. */
@Entity
@Table(name = "student_routines")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudentRoutine {

    @Id
    @Column(name = "student_id")
    private Long studentId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RoutineMode mode;

    /** "Pular": treino escolhido como proximo, valido ate a proxima sessao concluida. */
    private Long nextWorkoutId;
    private LocalDateTime nextSetAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;
}
