package com.felipebagarelli.gymmanager.controller;

import com.felipebagarelli.gymmanager.dto.request.CreateMemberRequest;
import com.felipebagarelli.gymmanager.dto.request.UpdateMemberRequest;
import com.felipebagarelli.gymmanager.dto.response.MemberResponse;
import com.felipebagarelli.gymmanager.service.MemberService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/members")
@CrossOrigin(origins = "http://localhost:5173")
public class MemberController {

    private MemberService memberService;

    public MemberController(MemberService memberService){
        this.memberService = memberService;
    }

    @PostMapping
    public MemberResponse addMembers(@RequestBody CreateMemberRequest request ){
        return memberService.addMember(request);
    }
    
    @GetMapping
    public List<MemberResponse> getAllMembers(){
        return memberService.findAllMembers();
    }

    @GetMapping("/{id}")
    public MemberResponse getMemberById(@PathVariable Long id){
        return memberService.findMemberById(id);
    }

    @DeleteMapping("/{id}")
    public void deleteMemberById(@PathVariable Long id){
        memberService.deleteById(id);
    }

    @PutMapping("/{id}")
    public MemberResponse updateMemberById(@PathVariable Long id, @RequestBody UpdateMemberRequest request){
        return memberService.updateById(id, request);
    }


}
