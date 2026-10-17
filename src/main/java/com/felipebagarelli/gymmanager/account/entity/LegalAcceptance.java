package com.felipebagarelli.gymmanager.account.entity;

import com.felipebagarelli.gymmanager.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Registro de um aceite: quem, qual documento e versao, quando e de onde. Nunca e apagado. */
@Entity
@Table(name = "legal_acceptances")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LegalAcceptance {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LegalDocument document;

    @Column(nullable = false)
    private String version;

    @Column(nullable = false)
    private LocalDateTime acceptedAt;

    private String ip;
    private String userAgent;

    /** Preenchidos no aceite do responsavel. */
    private String guardianName;
    private String guardianEmail;
}
