package com.felipebagarelli.gymmanager.student.service;

import com.felipebagarelli.gymmanager.billing.service.SubscriptionService;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignment;
import com.felipebagarelli.gymmanager.entity.WorkoutAssignmentStatus;
import com.felipebagarelli.gymmanager.repository.WorkoutAssignmentRepository;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class StudentLinkServiceTest {

    @Test
    void end_cancelsTheMonthlyFee_endsOnlyTheTrainersWorkouts_andKeepsTheAccount() {
        TrainerStudentRepository links = mock(TrainerStudentRepository.class);
        WorkoutAssignmentRepository assignments = mock(WorkoutAssignmentRepository.class);
        SubscriptionService subscriptions = mock(SubscriptionService.class);
        StudentProfile student = StudentProfile.builder().id(2L).name("Maria").active(true).build();
        TrainerStudent link = TrainerStudent.builder().id(9L).trainer(TrainerProfile.builder().id(1L).build())
                .student(student).status(TrainerStudentStatus.ACTIVE).build();
        WorkoutAssignment fromTrainer = WorkoutAssignment.builder().id(1L).student(student).status(WorkoutAssignmentStatus.ACTIVE)
                .workout(Workout.builder().id(10L).trainer(link.getTrainer()).build()).build();
        WorkoutAssignment own = WorkoutAssignment.builder().id(2L).student(student).status(WorkoutAssignmentStatus.ACTIVE)
                .workout(Workout.builder().id(11L).studentOwner(student).build()).build();
        when(assignments.findByStudentIdAndStatus(2L, WorkoutAssignmentStatus.ACTIVE)).thenReturn(List.of(fromTrainer, own));

        new StudentLinkService(links, assignments, subscriptions).end(link);

        verify(subscriptions).cancelActive(student);
        assertThat(link.getStatus()).isEqualTo(TrainerStudentStatus.CANCELED);
        assertThat(fromTrainer.getStatus()).isEqualTo(WorkoutAssignmentStatus.ENDED);
        assertThat(own.getStatus()).isEqualTo(WorkoutAssignmentStatus.ACTIVE);
        assertThat(student.isActive()).isTrue();
    }
}
