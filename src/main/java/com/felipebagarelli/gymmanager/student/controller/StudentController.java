package com.felipebagarelli.gymmanager.student.controller;

import com.felipebagarelli.gymmanager.student.dto.request.UpdateLinkStatusRequest;
import com.felipebagarelli.gymmanager.student.dto.request.UpdateStudentRequest;
import com.felipebagarelli.gymmanager.student.dto.response.StudentProfileResponse;
import com.felipebagarelli.gymmanager.student.service.StudentService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class StudentController {

    private final StudentService studentService;

    public StudentController(StudentService studentService) {
        this.studentService = studentService;
    }

    @GetMapping("/api/v1/trainers/{trainerId}/students")
    public List<StudentProfileResponse> listStudentsByTrainer(@PathVariable Long trainerId,
                                                               @AuthenticationPrincipal Jwt jwt) {
        return studentService.listByTrainer(trainerId, jwt.getSubject());
    }

    @GetMapping("/api/v1/students/me")
    public StudentProfileResponse getMyProfile(@AuthenticationPrincipal Jwt jwt) {
        return studentService.getMyProfile(jwt.getSubject());
    }

    @PutMapping("/api/v1/students/me")
    public StudentProfileResponse updateMyProfile(@RequestBody @Valid com.felipebagarelli.gymmanager.student.dto.request.UpdateMyProfileRequest request,
                                                  @AuthenticationPrincipal Jwt jwt) {
        return studentService.updateMyProfile(request, jwt.getSubject());
    }

    @GetMapping("/api/v1/students/{id}")
    public StudentProfileResponse getStudentById(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return studentService.getById(id, jwt.getSubject());
    }

    @PutMapping("/api/v1/students/{id}")
    public StudentProfileResponse updateStudent(@PathVariable Long id,
                                                 @RequestBody @Valid UpdateStudentRequest request,
                                                 @AuthenticationPrincipal Jwt jwt) {
        return studentService.updateById(id, request, jwt.getSubject());
    }

    @PostMapping("/api/v1/students/{id}/reactivate")
    public StudentProfileResponse reactivateStudent(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        return studentService.reactivate(id, jwt.getSubject());
    }

    @PutMapping("/api/v1/students/{id}/link-status")
    public StudentProfileResponse updateLinkStatus(@PathVariable Long id,
                                                   @RequestBody @Valid UpdateLinkStatusRequest request,
                                                   @AuthenticationPrincipal Jwt jwt) {
        return studentService.updateLinkStatus(id, request.status(), jwt.getSubject());
    }

    @DeleteMapping("/api/v1/students/{id}")
    public void deactivateStudent(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        studentService.deactivate(id, jwt.getSubject());
    }
}
