package com.felipebagarelli.gymmanager.service;

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

    public WorkoutAccessService(TrainerStudentRepository trainerStudentRepository,
                                StudentProfileRepository studentProfileRepository,
                                WorkoutAssignmentRepository workoutAssignmentRepository) {
        this.trainerStudentRepository = trainerStudentRepository;
        this.studentProfileRepository = studentProfileRepository;
        this.workoutAssignmentRepository = workoutAssignmentRepository;
    }

    public void assertCanWrite(Long studentId, String authenticatedEmail) {
        if (!isOwningTrainer(studentId, authenticatedEmail)) {
            throw new AccessDeniedException(DENIED_STUDENT);
        }
    }

    public void assertCanRead(Long studentId, String authenticatedEmail) {
        if (isOwningTrainer(studentId, authenticatedEmail) || isStudentThemselves(studentId, authenticatedEmail)) {
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
        if (isWorkoutOwner(workout, authenticatedEmail)
                || workoutAssignmentRepository.existsByWorkoutIdAndStudentUserEmail(workout.getId(), authenticatedEmail)) {
            return;
        }
        throw new AccessDeniedException(DENIED_WORKOUT);
    }

    private boolean isWorkoutOwner(Workout workout, String email) {
        return workout.getTrainer() != null
                && workout.getTrainer().getUser().getEmail().equalsIgnoreCase(email);
    }

    private boolean isOwningTrainer(Long studentId, String email) {
        return trainerStudentRepository.findByStudentId(studentId)
                .map(TrainerStudent::getTrainer)
                .map(trainer -> trainer.getUser().getEmail().equalsIgnoreCase(email))
                .orElse(false);
    }

    private boolean isStudentThemselves(Long studentId, String email) {
        StudentProfile student = studentProfileRepository.findById(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        return student.getUser().getEmail().equalsIgnoreCase(email);
    }
}
