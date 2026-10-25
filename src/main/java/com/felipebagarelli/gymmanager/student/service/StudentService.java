package com.felipebagarelli.gymmanager.student.service;

import com.felipebagarelli.gymmanager.exception.BadRequestException;
import com.felipebagarelli.gymmanager.exception.ConflictException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.session.entity.WorkoutSession;
import com.felipebagarelli.gymmanager.session.repository.WorkoutSessionRepository;
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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
public class StudentService {

    private final StudentProfileRepository studentProfileRepository;
    private final TrainerStudentRepository trainerStudentRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final WorkoutSessionRepository sessionRepository;
    private StudentLinkService linkService;

    @org.springframework.beans.factory.annotation.Autowired
    void setLinkService(StudentLinkService linkService) {
        this.linkService = linkService;
    }

    public StudentService(StudentProfileRepository studentProfileRepository,
                           TrainerStudentRepository trainerStudentRepository,
                           TrainerProfileRepository trainerProfileRepository,
                           WorkoutSessionRepository sessionRepository) {
        this.studentProfileRepository = studentProfileRepository;
        this.trainerStudentRepository = trainerStudentRepository;
        this.trainerProfileRepository = trainerProfileRepository;
        this.sessionRepository = sessionRepository;
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
                // vinculo encerrado aparece como inativo para o personal
                student.isActive() && status != TrainerStudentStatus.CANCELED,
                status,
                student.getWeeklyGoal(),
                sessionRepository.findFirstByAssignmentStudentIdAndFinishedAtIsNotNullOrderByStartedAtDesc(student.getId())
                        .map(WorkoutSession::getStartedAt)
                        .orElse(null)
        );
    }

    private void assertOwnership(TrainerProfile trainer, String authenticatedEmail) {
        if (!trainer.getUser().getEmail().equalsIgnoreCase(authenticatedEmail)) {
            throw new AccessDeniedException("Você não tem permissão para acessar os dados deste personal.");
        }
    }

    private TrainerStudent findOwningLink(Long studentId, String authenticatedEmail) {
        TrainerStudent link = trainerStudentRepository.findByStudentId(studentId)
                .filter(l -> !l.pendingPayment())
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        assertOwnership(link.getTrainer(), authenticatedEmail);
        return link;
    }

    public List<StudentProfileResponse> listByTrainer(Long trainerId, String authenticatedEmail) {
        TrainerProfile trainer = trainerProfileRepository.findById(trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!"));
        assertOwnership(trainer, authenticatedEmail);

        return trainerStudentRepository.findByTrainerId(trainerId).stream()
                // contratacao pelo hub ainda nao paga nao aparece
                .filter(link -> !link.pendingPayment())
                .map(link -> toResponse(link.getStudent(), link.getStatus()))
                .toList();
    }

    /**
     * Perfil de um aluno: só o personal dono do vínculo ou o próprio aluno.
     * Qualquer outro usuário recebe 403 (não basta conhecer o id).
     */
    public StudentProfileResponse getById(Long id, String authenticatedEmail) {
        StudentProfile student = studentProfileRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        Optional<TrainerStudent> link = trainerStudentRepository.findByStudentId(id);

        boolean ownTrainer = link.filter(l -> !l.pendingPayment())
                .map(l -> l.getTrainer().getUser().getEmail().equalsIgnoreCase(authenticatedEmail))
                .orElse(false);
        boolean self = student.getUser().getEmail().equalsIgnoreCase(authenticatedEmail);
        if (!ownTrainer && !self) {
            throw new AccessDeniedException("Você não tem permissão para acessar os dados deste aluno.");
        }

        return toResponse(student, link.map(TrainerStudent::getStatus).orElse(null));
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
        } else if (Boolean.TRUE.equals(request.clearWeeklyGoal())) {
            student.setWeeklyGoal(null);
        }
        studentProfileRepository.save(student);

        return toResponse(student, link.getStatus());
    }

    @Transactional
    public void deactivate(Long id, String authenticatedEmail) {
        // o aluno nao perde o app: o acompanhamento acaba e ele volta ao plano gratis
        linkService.end(findOwningLink(id, authenticatedEmail));
    }

    /** Desfaz o "desativar": o aluno volta a poder usar o chat e a aparecer como ativo. */
    @Transactional
    public StudentProfileResponse reactivate(Long id, String authenticatedEmail) {
        TrainerStudent link = findOwningLink(id, authenticatedEmail);
        StudentProfile student = link.getStudent();
        student.setActive(true);
        studentProfileRepository.save(student);
        if (link.getStatus() == TrainerStudentStatus.CANCELED) {
            link.setStatus(TrainerStudentStatus.ACTIVE);
            trainerStudentRepository.save(link);
        }
        return toResponse(student, link.getStatus());
    }

    /**
     * Pausa ou retoma o vinculo (ex.: aluno de ferias). Pausado, o chat fica fechado e o aluno nao
     * assina planos novos. A cobranca no provedor NAO e pausada: isso continua com o personal.
     */
    @Transactional
    public StudentProfileResponse updateLinkStatus(Long id, TrainerStudentStatus status, String authenticatedEmail) {
        if (status != TrainerStudentStatus.ACTIVE && status != TrainerStudentStatus.PAUSED) {
            throw new BadRequestException("Só é possível pausar ou retomar o acompanhamento.");
        }
        TrainerStudent link = findOwningLink(id, authenticatedEmail);
        if (link.getStatus() != TrainerStudentStatus.ACTIVE && link.getStatus() != TrainerStudentStatus.PAUSED) {
            throw new ConflictException("Este vínculo não pode mais ser alterado.");
        }
        link.setStatus(status);
        trainerStudentRepository.save(link);
        return toResponse(link.getStudent(), status);
    }

    /** O proprio aluno corrige os dados (LGPD: retificacao). */
    @Transactional
    public StudentProfileResponse updateMyProfile(com.felipebagarelli.gymmanager.student.dto.request.UpdateMyProfileRequest request,
                                                  String authenticatedEmail) {
        StudentProfile student = studentProfileRepository.findByUserEmail(authenticatedEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Aluno não encontrado!"));
        student.setName(request.name().trim());
        student.setPhone(request.phone() == null || request.phone().isBlank() ? null : request.phone().trim());
        student.setHeight(request.height());
        student.setWeight(request.weight());
        studentProfileRepository.save(student);
        return getMyProfile(authenticatedEmail);
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
