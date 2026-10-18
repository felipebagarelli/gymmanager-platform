package com.felipebagarelli.gymmanager.platformplan.entity;

import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Assinatura do plano da plataforma (GymManager Pro) de um aluno sem personal. */
@Entity
@Table(name = "platform_subscriptions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlatformSubscription {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "student_id", nullable = false)
    private StudentProfile student;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PlatformSubscriptionStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "billing_interval", nullable = false)
    private BillingInterval billingInterval;

    private int priceCents;

    @Column(unique = true)
    private String stripeSubscriptionId;

    private LocalDateTime currentPeriodEnd;
    private LocalDateTime trialEnd;

    /** Cancelou, mas continua Pro ate o fim do periodo pago. */
    private boolean cancelAtPeriodEnd;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;
}
