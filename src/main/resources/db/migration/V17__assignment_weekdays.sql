-- V17: dias da semana de cada treino atribuido (Fase F2). Mascara de bits: segunda = 1, terca = 2,
-- quarta = 4 ... domingo = 64. Zero = treino "livre" (sem dia marcado), como antes.

ALTER TABLE workout_assignments ADD COLUMN weekdays integer NOT NULL DEFAULT 0
    CHECK (weekdays >= 0 AND weekdays < 128);
