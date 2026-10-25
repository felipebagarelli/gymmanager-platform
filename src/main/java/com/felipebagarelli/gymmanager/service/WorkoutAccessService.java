package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.billing.service.BillingAccessGuard;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

@Service
public class WorkoutAccessService {

    private static final String DENIED_STUDENT = "Você não tem permissão para acessar os treinos deste aluno.";
    private static final String DENIED_WORKOUT = "Você não tem permissão para acessar este treino.";

    private final TrainerStudentRepository trainerStudentRepository;
    private final StudentProfileRepository studentProfileRepository;
    private final WorkoutAssignmentRepository workoutAssignmentRepository;
    private final BillingAccessGuard billingAccessGuard;

    public WorkoutAccessService(TrainerStudentRepository trainerStudentRepository,
                                StudentProfileRepository studentProfileRepository,
                                WorkoutAssignmentRepository workoutAssignmentRepository,
                                BillingAccessGuard billingAccessGuard) {
        this.trainerStudentRepository = trainerStudentRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.workoutAssignmentRepository = workoutAssignmentRepository;
        this.billingAccessGuard = billingAccessGuard;
    }

    /** Escrever (atribuir, agenda): so com o acompanhamento ativo ou pausado. Ler o historico vale tambem depois. */
    public void assertCanWrite(Long studentId, String authenticatedEmail) {
        if (!isOwningTrainer(studentId, authenticatedEmail) || !isCurrentLink(studentId)) {
            throw new AccessDeniedException(DENIED_STUDENT);
        }
    }

    public void assertCanRead(Long studentId, String authenticatedEmail) {
        if (isOwningTrainer(studentId, authenticatedEmail)) {
            return;
        }
        if (isStudentThemselves(studentId, authenticatedEmail)) {
            billingAccessGuard.assertStudentNotBlocked(studentId);
            return;
        }
        throw new AccessDeniedException(DENIED_STUDENT);
    }

    public void assertOwnsWorkout(Workout workout, String authenticatedEmail) {
        if (!isWorkoutOwner(workout, authenticatedEmail)) {
            throw new AccessDeniedException(DENIED_WORKOUT);
        }
    }

    public void assertCanReadWorkout(Workout workout, String authenticatedEmail) {
        if (isWorkoutOwner(workout, authenticatedEmail)) {
            return;
        }
        if (workoutAssignmentRepository.existsByWorkoutIdAndStudentUserEmail(workout.getId(), authenticatedEmail)) {
            billingAccessGuard.assertStudentNotBlockedByEmail(authenticatedEmail);
            return;
        }
        throw new AccessDeniedException(DENIED_WORKOUT);
    }

    /** O personal acompanha (ativo ou pausado) este aluno. */
    public boolean isCurrentTrainerOf(Long studentId, Long trainerId) {
        return trainerStudentRepository.findByStudentId(studentId)
                .filter(link -> link.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.ACTIVE
                        || link.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.PAUSED)
                .map(link -> link.getTrainer().getId().equals(trainerId))
                .orElse(false);
    }

    /** O proprio aluno (nao o personal dele) e dono deste treino. */
    public boolean isStudentOwner(Workout workout, String email) {
        return workout.getStudentOwner() != null && workout.getStudentOwner().getUser().getEmail().equalsIgnoreCase(email);
    }

    /** Dono: o personal que montou ou, no treino do aluno sem personal, o proprio aluno. */
    private boolean isWorkoutOwner(Workout workout, String email) {
        if (workout.getTrainer() != null) {
            return workout.getTrainer().getUser().getEmail().equalsIgnoreCase(email);
        }
        if (workout.getStudentOwner() == null) return false;
        if (workout.getStudentOwner().getUser().getEmail().equalsIgnoreCase(email)) return true;
        // o personal do aluno tambem pode editar os treinos que o aluno montou
        return trainerStudentRepository.findByStudentId(workout.getStudentOwner().getId())
                .filter(link -> link.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.ACTIVE
                        || link.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.PAUSED)
                .map(link -> link.getTrainer().getUser().getEmail().equalsIgnoreCase(email))
                .orElse(false);
    }

    private boolean isOwningTrainer(Long studentId, String email) {
        return trainerStudentRepository.findByStudentId(studentId)
                // contratacao pelo hub ainda nao paga: o personal nao acessa nada
                .filter(link -> !link.pendingPayment())
                .map(TrainerStudent::getTrainer)
                .map(trainer -> trainer.getUser().getEmail().equalsIgnoreCase(email))
                .orElse(false);
    }

    private boolean isCurrentLink(Long studentId) {
        return trainerStudentRepository.findByStudentId(studentId)
                .map(link -> link.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.ACTIVE
                        || link.getStatus() == com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus.PAUSED)
                .orElse(false);
    }

    private boolean isStudentThemselves(Long studentId, String email) {
        StudentProfile student = studentProfileRepository.findById(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        return student.getUser().getEmail().equalsIgnoreCase(email);
    }
}
