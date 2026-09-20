package com.felipebagarelli.gymmanager.billing.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** Registro de evento da Stripe ja processado (idempotencia). */
@Entity
@Table(name = "billing_events")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BillingEvent {
    @Id
    @Column(name = "stripe_event_id")
    private String stripeEventId;

    @Column(nullable = false)
    private LocalDateTime receivedAt;
}
