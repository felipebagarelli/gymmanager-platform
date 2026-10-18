package com.felipebagarelli.gymmanager.trainer.entity;

import com.felipebagarelli.gymmanager.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "trainer_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainerProfile {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    private String displayName;
    private String phone;
    private String bio;

    // ---- perfil publico no hub (Fase E): so aparece se listed = true e puder receber
    private boolean listed;
    private String headline;
    private String city;
    private String state;
    @Builder.Default
    private boolean online = true;
    private boolean inPerson;
    /** Especialidades separadas por virgula (TrainerSpecialty). */
    private String specialties;
}
