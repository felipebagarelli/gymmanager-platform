-- V11: treino montado pelo proprio aluno sem personal (C6). Um treino pertence a um personal
-- (trainer_id) OU a um aluno (student_owner_id). Na Fase D, a IA propoe treinos para esse mesmo dono.

ALTER TABLE workout ADD COLUMN student_owner_id bigint REFERENCES student_profiles(id);

-- Treinos antigos sem dono (de antes de gravar quem montou): ficam com o personal dos alunos que os
-- receberam; sem aluno, com o unico personal cadastrado (bancos de desenvolvimento).
UPDATE workout w
   SET trainer_id = (SELECT min(ts.trainer_id)
                       FROM workout_assignments a
                       JOIN trainer_students ts ON ts.student_id = a.student_id
                      WHERE a.workout_id = w.id)
 WHERE w.trainer_id IS NULL;
UPDATE workout
   SET trainer_id = (SELECT min(id) FROM trainer_profiles)
 WHERE trainer_id IS NULL
   AND (SELECT count(*) FROM trainer_profiles) = 1;

-- NOT VALID: vale para treinos novos e alterados; algum antigo que ainda sobrar sem dono nao trava a
-- migracao (continua visivel so para os alunos que o receberam).
ALTER TABLE workout ADD CONSTRAINT workout_has_owner CHECK (trainer_id IS NOT NULL OR student_owner_id IS NOT NULL) NOT VALID;
CREATE INDEX idx_workout_student_owner ON workout (student_owner_id);
