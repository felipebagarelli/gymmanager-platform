package com.felipebagarelli.gymmanager.session.entity;

import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "workout_sessions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkoutSession {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "assignment_id", nullable = false)
    private WorkoutAssignment assignment;

    private LocalDateTime startedAt;
    private LocalDateTime finishedAt;
}
