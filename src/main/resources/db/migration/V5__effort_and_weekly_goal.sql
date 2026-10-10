-- V5: "Como foi?" (esforco percebido da serie) e meta semanal do aluno. Ambos opcionais.

ALTER TABLE exercise_performances
    ADD COLUMN effort varchar(255) CHECK (effort IN ('EASY', 'IDEAL', 'HARD'));

ALTER TABLE student_profiles
    ADD COLUMN weekly_goal integer CHECK (weekly_goal BETWEEN 1 AND 14);
