package com.felipebagarelli.gymmanager.dto.request;

import java.time.LocalDate;

public record CreateMemberRequest(String name, String email,
                                  String phone, LocalDate birthDate, Double height, Double weight) {
}
