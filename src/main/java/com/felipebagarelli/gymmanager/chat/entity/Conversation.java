package com.felipebagarelli.gymmanager.chat.entity;

import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "conversations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Conversation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "trainer_student_id", nullable = false, unique = true)
    private TrainerStudent trainerStudent;

    private LocalDateTime createdAt;

    /** Ultimo id de mensagem lido por cada lado; null = nada lido ainda. */
    private Long trainerLastReadId;
    private Long studentLastReadId;

    public Long lastReadBy(MessageSender side) {
        return side == MessageSender.TRAINER ? trainerLastReadId : studentLastReadId;
    }

    public void markReadBy(MessageSender side, Long messageId) {
        if (side == MessageSender.TRAINER) {
            trainerLastReadId = messageId;
        } else {
            studentLastReadId = messageId;
        }
    }
}
