package com.felipebagarelli.gymmanager.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
@Entity
@Table(name = "members")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Member {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String email;
    private String phone;
    private LocalDate birthDate;
    private Double height;
    private Double weight;
    private boolean active;
}
