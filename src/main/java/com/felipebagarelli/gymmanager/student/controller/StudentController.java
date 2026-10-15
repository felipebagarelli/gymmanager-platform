package com.felipebagarelli.gymmanager.student.controller;

import com.felipebagarelli.gymmanager.student.dto.request.CreateStudentRequest;
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

    @PostMapping("/api/v1/trainers/{trainerId}/students")
    public StudentProfileResponse createStudent(@PathVariable Long trainerId,
                                                 @RequestBody @Valid CreateStudentRequest request,
                                                 @AuthenticationPrincipal Jwt jwt) {
        return studentService.createStudent(trainerId, request, jwt.getSubject());
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

    @DeleteMapping("/api/v1/students/{id}")
    public void deactivateStudent(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        studentService.deactivate(id, jwt.getSubject());
    }
}
