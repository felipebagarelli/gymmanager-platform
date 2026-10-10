package com.felipebagarelli.gymmanager.student.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.EmailAlreadyInUseException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.student.dto.request.CreateStudentRequest;
import com.felipebagarelli.gymmanager.student.dto.request.UpdateStudentRequest;
import com.felipebagarelli.gymmanager.student.dto.response.StudentProfileResponse;
import com.felipebagarelli.gymmanager.student.entity.StudentProfile;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudent;
import com.felipebagarelli.gymmanager.student.entity.TrainerStudentStatus;
import com.felipebagarelli.gymmanager.student.repository.StudentProfileRepository;
import com.felipebagarelli.gymmanager.student.repository.TrainerStudentRepository;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class StudentService {

    private final StudentProfileRepository studentProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public StudentService(StudentProfileRepository studentProfileRepository,
                           TrainerStudentRepository trainerStudentRepository,
                           TrainerProfileRepository trainerProfileRepository,
                           UserRepository userRepository,
                           PasswordEncoder passwordEncoder) {
        this.studentProfileRepository = studentProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    private StudentProfileResponse toResponse(StudentProfile student, TrainerStudentStatus status) {
        return new StudentProfileResponse(
                student.getId(),
                student.getUser().getEmail(),
                student.getName(),
                student.getBirthDate(),
                student.getPhone(),
                student.getGoal(),
                student.getHeight(),
                student.getWeight(),
                student.isActive(),
                status,
                student.getWeeklyGoal()
        );
    }

    private void assertOwnership(TrainerProfile trainer, String authenticatedEmail) {
        if (!trainer.getUser().getEmail().equalsIgnoreCase(authenticatedEmail)) {
            throw new AccessDeniedException("Você não tem permissão para acessar os dados deste personal.");
        }
    }

    private TrainerStudent findOwningLink(Long studentId, String authenticatedEmail) {
        TrainerStudent link = trainerStudentRepository.findByStudentId(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        assertOwnership(link.getTrainer(), authenticatedEmail);
        return link;
    }

    @Transactional
    public StudentProfileResponse createStudent(Long trainerId, CreateStudentRequest request, String authenticatedEmail) {
        TrainerProfile trainer = trainerProfileRepository.findById(trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
        assertOwnership(trainer, authenticatedEmail);

        if (userRepository.existsByEmail(request.email())) {
            throw new EmailAlreadyInUseException("E-mail já está em uso!");
        }

        LocalDateTime now = LocalDateTime.now();
        User user = User.builder()
                .email(request.email())
                .passwordHash(passwordEncoder.encode(request.password()))
                .role(Role.STUDENT)
                .active(true)
                .createdAt(now)
                .updatedAt(now)
                .build();
        userRepository.save(user);

        StudentProfile student = StudentProfile.builder()
                .user(user)
                .name(request.name())
                .birthDate(request.birthDate())
                .phone(request.phone())
                .goal(request.goal())
                .height(request.height())
                .weight(request.weight())
                .active(true)
                .build();
        studentProfileRepository.save(student);

        TrainerStudent trainerStudent = TrainerStudent.builder()
                .trainer(trainer)
                .student(student)
                .status(TrainerStudentStatus.ACTIVE)
                .createdAt(now)
                .build();
        trainerStudentRepository.save(trainerStudent);

        return toResponse(student, trainerStudent.getStatus());
    }

    public List<StudentProfileResponse> listByTrainer(Long trainerId, String authenticatedEmail) {
        TrainerProfile trainer = trainerProfileRepository.findById(trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
        assertOwnership(trainer, authenticatedEmail);

        return trainerStudentRepository.findByTrainerId(trainerId).stream()
                .map(link -> toResponse(link.getStudent(), link.getStatus()))
                .toList();
    }

    public StudentProfileResponse getById(Long id) {
        StudentProfile student = studentProfileRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));

        TrainerStudentStatus status = trainerStudentRepository.findByStudentId(id)
                .map(TrainerStudent::getStatus)
                .orElse(null);

        return toResponse(student, status);
    }

    @Transactional
    public StudentProfileResponse updateById(Long id, UpdateStudentRequest request, String authenticatedEmail) {
        TrainerStudent link = findOwningLink(id, authenticatedEmail);
        StudentProfile student = link.getStudent();

        student.setName(request.name());
        student.setBirthDate(request.birthDate());
        student.setPhone(request.phone());
        student.setGoal(request.goal());
        student.setHeight(request.height());
        student.setWeight(request.weight());
        // aditivo: quem não envia a meta (ex.: painel atual) não apaga a que já existe
        if (request.weeklyGoal() != null) {
            student.setWeeklyGoal(request.weeklyGoal());
        }
        studentProfileRepository.save(student);

        return toResponse(student, link.getStatus());
    }

    @Transactional
    public void deactivate(Long id, String authenticatedEmail) {
        TrainerStudent link = findOwningLink(id, authenticatedEmail);
        StudentProfile student = link.getStudent();
        student.setActive(false);
        studentProfileRepository.save(student);
    }

    public StudentProfileResponse getMyProfile(String authenticatedEmail) {
        StudentProfile student = studentProfileRepository.findByUserEmail(authenticatedEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));

        TrainerStudentStatus status = trainerStudentRepository.findByStudentId(student.getId())
                .map(TrainerStudent::getStatus)
                .orElse(null);

        return toResponse(student, status);
    }
}
