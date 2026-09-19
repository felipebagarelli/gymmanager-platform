package com.felipebagarelli.gymmanager.student.entity;

import com.felipebagarelli.gymmanager.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "student_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudentProfile {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    private String name;
    private LocalDate birthDate;
    private String phone;
    private String goal;
    private Double height;
    private Double weight;
    private boolean active;
}
