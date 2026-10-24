package com.felipebagarelli.gymmanager.student.service;

import com.felipebagarelli.gymmanager.billing.service.SubscriptionService;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * Fim do acompanhamento: o aluno continua com a conta e volta ao plano gratis (treinos proprios e
 * historico ficam; os treinos do personal saem da lista; a mensalidade com o personal e cancelada).
 */
@Service
public class StudentLinkService {

    private final TrainerStudentRepository trainerStudentRepository;
    private final WorkoutAssignmentRepository assignmentRepository;
    private final SubscriptionService subscriptionService;

    public StudentLinkService(TrainerStudentRepository trainerStudentRepository,
                              WorkoutAssignmentRepository assignmentRepository,
                              SubscriptionService subscriptionService) {
        this.trainerStudentRepository = trainerStudentRepository;
        this.assignmentRepository = assignmentRepository;
        this.subscriptionService = subscriptionService;
    }

    @Transactional
    public void end(TrainerStudent link) {
        subscriptionService.cancelActive(link.getStudent());
        for (WorkoutAssignment a : assignmentRepository.findByStudentIdAndStatus(link.getStudent().getId(), WorkoutAssignmentStatus.ACTIVE)) {
            // so os treinos do personal; os que o aluno montou continuam
            if (a.getWorkout().getTrainer() != null) {
                a.setStatus(WorkoutAssignmentStatus.ENDED);
                a.setEndedAt(LocalDateTime.now());
                assignmentRepository.save(a);
            }
        }
        link.setStatus(TrainerStudentStatus.CANCELED);
        trainerStudentRepository.save(link);
    }
}
