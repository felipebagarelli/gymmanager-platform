package com.felipebagarelli.gymmanager.entity;

import com.felipebagarelli.gymmanager.exception.BadRequestException;

import java.util.ArrayList;
import java.util.List;

/** Dias da semana de uma atribuicao: 1 = segunda ... 7 = domingo (ISO), guardados como mascara de bits. */
public final class Weekdays {

    private Weekdays() {
    }

    public static int toMask(List<Integer> days) {
        if (days == null) return 0;
        int mask = 0;
        for (Integer day : days) {
            if (day == null || day < 1 || day > 7) {
                throw new BadRequestException("Dia da semana inválido: use de 1 (segunda) a 7 (domingo).");
            }
            mask |= 1 << (day - 1);
        }
        return mask;
    }

    public static List<Integer> fromMask(int mask) {
        List<Integer> days = new ArrayList<>();
        for (int day = 1; day <= 7; day++) {
            if ((mask & (1 << (day - 1))) != 0) days.add(day);
        }
        return days;
    }
}
