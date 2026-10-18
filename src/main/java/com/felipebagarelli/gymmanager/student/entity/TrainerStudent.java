package com.felipebagarelli.gymmanager.student.entity;

import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "trainer_students")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainerStudent {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "trainer_id", nullable = false)
    private TrainerProfile trainer;

    @ManyToOne
    @JoinColumn(name = "student_id", nullable = false)
    private StudentProfile student;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TrainerStudentStatus status;

    private LocalDateTime createdAt;

    /** Contratacao pelo hub aguardando o pagamento: o personal ainda nao ve nada do aluno. */
    public boolean pendingPayment() {
        return status == TrainerStudentStatus.INVITED;
    }
}
