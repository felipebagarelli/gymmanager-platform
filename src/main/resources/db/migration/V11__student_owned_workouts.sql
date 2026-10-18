-- V11: treino montado pelo proprio aluno sem personal (C6). Um treino pertence a um personal
-- (trainer_id) OU a um aluno (student_owner_id). Na Fase D, a IA propoe treinos para esse mesmo dono.

ALTER TABLE workout ADD COLUMN student_owner_id bigint REFERENCES student_profiles(id);
ALTER TABLE workout ADD CONSTRAINT workout_has_owner CHECK (trainer_id IS NOT NULL OR student_owner_id IS NOT NULL);
CREATE INDEX idx_workout_student_owner ON workout (student_owner_id);
