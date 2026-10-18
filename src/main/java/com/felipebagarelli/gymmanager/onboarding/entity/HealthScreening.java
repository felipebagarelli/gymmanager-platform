package com.felipebagarelli.gymmanager.onboarding.entity;

import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Uma resposta da triagem de saude. Nunca e alterada: responder de novo cria outra. */
@Entity
@Table(name = "health_screenings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HealthScreening {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "student_id", nullable = false)
    private StudentProfile student;

    @Column(nullable = false)
    private String version;

    /** Uma letra por pergunta, na ordem: S = sim, N = nao. */
    @Column(nullable = false)
    private String answers;

    /** Alguma resposta "sim": recomendar avaliacao e bloquear treino gerado por IA. */
    private boolean risk;

    @Column(nullable = false)
    private LocalDateTime answeredAt;
}
