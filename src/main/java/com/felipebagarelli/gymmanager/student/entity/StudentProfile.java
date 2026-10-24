package com.felipebagarelli.gymmanager.student.entity;

import com.felipebagarelli.gymmanager.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "student_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudentProfile {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    private String name;
    private LocalDate birthDate;
    private String phone;
    private String goal;
    private Double height;
    private Double weight;
    /** Meta de treinos por semana (opcional, 1 a 14). */
    private Integer weeklyGoal;
    private boolean active;

    /** Responsavel legal (aluno de 12 a 17 anos que se cadastrou sozinho). */
    private String guardianName;
    private String guardianEmail;

    /** Quando o responsavel autorizou (null = ainda nao autorizou, se houver responsavel). */
    private LocalDateTime guardianConsentAt;

    /** O aluno autorizou o personal a ver a triagem de saude e o perfil de treino. */
    private boolean shareHealthWithTrainer;
}
