package com.felipebagarelli.gymmanager.dto.response;

import com.felipebagarelli.gymmanager.entity.Member;

public record WorkoutResponse(
        Long id,
        String name,
        Member member
) {
}
