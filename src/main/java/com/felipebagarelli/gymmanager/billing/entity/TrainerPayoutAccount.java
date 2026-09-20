package com.felipebagarelli.gymmanager.billing.entity;

import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Conta conectada (Stripe Connect) que recebe os pagamentos do personal. */
@Entity
@Table(name = "trainer_payout_accounts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainerPayoutAccount {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "trainer_id", nullable = false, unique = true)
    private TrainerProfile trainer;

    @Column(nullable = false, unique = true)
    private String stripeAccountId;

    @Column(nullable = false)
    private boolean chargesEnabled;

    @Column(nullable = false)
    private LocalDateTime updatedAt;
}
