package com.felipebagarelli.gymmanager.entity;


import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "exercises")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Exercises {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String muscleGroup;

}
