-- V18: esquema rotativo (Fase F3). O aluno segue os dias da semana (F2) OU uma sequencia de treinos
-- (AB, ABC...) em que o proximo e o seguinte ao ultimo concluido, independente do dia.
--   * workout_assignments.rotation_order: posicao do treino na sequencia (null = fora dela).
--   * student_routines: o modo do aluno e o "pular" manual (proximo escolhido e quando).

ALTER TABLE workout_assignments ADD COLUMN rotation_order integer CHECK (rotation_order > 0);

CREATE TABLE student_routines (
    student_id bigint PRIMARY KEY REFERENCES student_profiles(id),
    mode varchar(16) NOT NULL CHECK (mode IN ('WEEKDAYS', 'ROTATION')),
    next_workout_id bigint REFERENCES workout(id),
    next_set_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone NOT NULL
);
