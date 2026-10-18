package com.felipebagarelli.gymmanager.aiworkout.entity;

import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Proposta de treino da IA (auditoria): nada vira treino ate o aluno aceitar. */
@Entity
@Table(name = "ai_workout_proposals")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiWorkoutProposal {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "student_id", nullable = false)
    private StudentProfile student;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ProposalStatus status;

    /** O que o aluno pediu (opcional, curto). */
    private String requestNote;

    /** Proposta ja validada pelo servidor (JSON). */
    @Column(nullable = false, columnDefinition = "text")
    private String proposalJson;

    private long inputTokens;
    private long outputTokens;

    /** Treinos criados no aceite (ids separados por virgula). */
    private String workoutIds;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    private LocalDateTime decidedAt;
}
