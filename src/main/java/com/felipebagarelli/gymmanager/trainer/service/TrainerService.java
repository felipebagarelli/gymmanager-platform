package com.felipebagarelli.gymmanager.trainer.service;

import com.felipebagarelli.gymmanager.auth.entity.Role;
import com.felipebagarelli.gymmanager.auth.entity.User;
import com.felipebagarelli.gymmanager.auth.repository.UserRepository;
import com.felipebagarelli.gymmanager.exception.EmailAlreadyInUseException;
import com.felipebagarelli.gymmanager.exception.ResourceNotFoundException;
import com.felipebagarelli.gymmanager.trainer.dto.request.RegisterTrainerRequest;
import com.felipebagarelli.gymmanager.trainer.dto.response.TrainerProfileResponse;
import com.felipebagarelli.gymmanager.trainer.entity.TrainerProfile;
import com.felipebagarelli.gymmanager.trainer.repository.TrainerProfileRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
public class TrainerService {

    private final TrainerProfileRepository trainerProfileRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public TrainerService(TrainerProfileRepository trainerProfileRepository,
                           UserRepository userRepository,
                           PasswordEncoder passwordEncoder) {
        this.trainerProfileRepository = trainerProfileRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    private TrainerProfileResponse toResponse(TrainerProfile trainerProfile) {
        return new TrainerProfileResponse(
                trainerProfile.getId(),
                trainerProfile.getUser().getEmail(),
                trainerProfile.getDisplayName(),
                trainerProfile.getPhone()
        );
    }

    @Transactional
    public TrainerProfileResponse registerTrainer(RegisterTrainerRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new EmailAlreadyInUseException("E-mail já está em uso!");
        }

        LocalDateTime now = LocalDateTime.now();
        User user = User.builder()
                .email(request.email())
                .passwordHash(passwordEncoder.encode(request.password()))
                .role(Role.TRAINER)
                .active(true)
                .createdAt(now)
                .updatedAt(now)
                .build();
        userRepository.save(user);

        TrainerProfile trainerProfile = TrainerProfile.builder()
                .user(user)
                .displayName(request.displayName())
                .phone(request.phone())
                .build();
        trainerProfileRepository.save(trainerProfile);

        return toResponse(trainerProfile);
    }

    public TrainerProfileResponse getTrainerById(Long id) {
        return toResponse(trainerProfileRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!")));
    }

    public TrainerProfileResponse getMyProfile(String authenticatedEmail) {
        return toResponse(trainerProfileRepository.findByUserEmail(authenticatedEmail)
                .orElseThrow(() -> new ResourceNotFoundException("Personal não encontrado!")));
    }
}
