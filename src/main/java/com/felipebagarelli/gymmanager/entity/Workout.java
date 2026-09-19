package com.felipebagarelli.gymmanager.entity;


import jakarta.persistence.*;
import lombok.*;

@Entity
@NoArgsConstructor
@AllArgsConstructor
@Getter
@Setter
@Table(name = "workout")
@Builder
public class Workout {
            @Id
            @GeneratedValue(strategy = GenerationType.IDENTITY)
            private Long id;
            private String name;
            @ManyToOne
            @JoinColumn(name = "merber_id")
            private Member member;

}
//TENHO Q COLOCAR O WORKOUT NO MEMBER COMO ONTETOMANY, POIS EU QUERO SABER OS TREINOS DE UM MEMBRO E NAO A QUAL MEMBRO CORRESPONDE DETERMINADO TREINO!