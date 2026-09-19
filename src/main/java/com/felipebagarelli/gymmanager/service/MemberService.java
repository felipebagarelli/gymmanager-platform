package com.felipebagarelli.gymmanager.service;

import com.felipebagarelli.gymmanager.dto.request.CreateMemberRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateMemberRequest;
import com.felipebagarelli.gymmanager.dto.response.MemberResponse;
import com.felipebagarelli.gymmanager.entity.Member;
import com.felipebagarelli.gymmanager.repository.MemberRepository;
import org.springframework.stereotype.Service;

import java.util.List;


@Service
public class MemberService {

    private final MemberRepository memberRepository;

    private MemberResponse toResponse(Member member) {
        return new MemberResponse(
                member.getId(),
                member.getName(),
                member.getEmail(),
                member.getPhone(),
                member.getBirthDate(),
                member.getHeight(),
                member.getWeight(),
                member.isActive()
        );
    }


    public MemberService(MemberRepository memberRepository){
        this.memberRepository = memberRepository;
    }

    public MemberResponse addMember(CreateMemberRequest request){

        Member member = Member.builder()
                .name(request.name())
                .email(request.email())
                .phone(request.phone())
                .birthDate(request.birthDate())
                .height(request.height())
                .weight(request.weight())
                .active(true)
                .build();

        Member savedMember = memberRepository.save(member);

        return new MemberResponse(
                savedMember.getId(),
                savedMember.getName(),
                savedMember.getEmail(),
                savedMember.getPhone(),
                savedMember.getBirthDate(),
                savedMember.getHeight(),
                savedMember.getWeight(),
                savedMember.isActive());
    }

    public List<MemberResponse> findAllMembers(){

        return memberRepository.findAll().stream().map(this::toResponse).toList();
    }

    public MemberResponse findMemberById(Long id){
        return toResponse(memberRepository.findById(id).orElseThrow());
    }

    public void deleteById(Long id){
        memberRepository.deleteById(id);
    }

    public MemberResponse updateById(Long id, UpdateMemberRequest request){
        Member member = memberRepository.findById(id).orElseThrow();
        member.setName(request.name());
        member.setPhone(request.phone());
        member.setEmail(request.email());
        member.setBirthDate(request.birthDate());
        member.setHeight(request.height());
        member.setWeight(request.weight());
        memberRepository.save(member);

        return toResponse(member);
    }


}
