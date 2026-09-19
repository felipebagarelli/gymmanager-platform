package com.felipebagarelli.gymmanager.service;


import com.felipebagarelli.gymmanager.dto.request.CreateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateWorkoutRequest;
import com.felipebagarelli.gymmanager.dto.response.WorkoutResponse;
import com.felipebagarelli.gymmanager.entity.Member;
import com.felipebagarelli.gymmanager.entity.Workout;
import com.felipebagarelli.gymmanager.repository.MemberRepository;
import com.felipebagarelli.gymmanager.repository.WorkoutRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class WorkoutService {

    private final WorkoutRepository workoutRepository;
    private final MemberRepository memberRepository;

    public WorkoutService(WorkoutRepository workoutRepository, MemberRepository memberRepository){
        this.workoutRepository = workoutRepository;
        this.memberRepository = memberRepository;
    }

    public WorkoutResponse toResponse(Workout workout){
        return new WorkoutResponse(workout.getId(), workout.getName(), workout.getMember());
    }

    public WorkoutResponse addWorkout(CreateWorkoutRequest request){

        Member member = memberRepository.findById(request.memberId()).orElseThrow();

        Workout workout = Workout.builder()
                .name(request.name())
                .member(member)
                .build();

        workoutRepository.save(workout);
        return toResponse(workout);
    }

    public List<WorkoutResponse> allWorkout (Long id){
        List<Workout> listWorkout = workoutRepository.findByMemberId(id);
        return listWorkout.stream().map(this::toResponse).toList();
    }

    public void deleteById (Long id){
        workoutRepository.deleteById(id);
    }

    public WorkoutResponse getWorkoutById (Long id){
        return toResponse(workoutRepository.findById(id).orElseThrow());
    }

    public WorkoutResponse updateById(Long id, UpdateWorkoutRequest request){
        Member member = memberRepository.findById(request.memberId()).orElseThrow();
        Workout workout = workoutRepository.findById(id).orElseThrow();
        workout.setName(request.name());
        workout.setMember(member);
        workoutRepository.save(workout);
        return toResponse(workout);
    }






}
