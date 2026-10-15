-- V7: biblioteca de exercicios por personal e remocao de exercicio do treino sem perder o historico.
--   * exercises.trainer_id: dono do exercicio. NULL = catalogo comum (somente leitura pela API).
--     Os exercicios que ja existiam ficam no catalogo comum.
--   * workout_exercises.removed_at: exercicio retirado do treino depois de ja ter series registradas.
--     Some do plano, mas as series antigas continuam apontando para ele.

ALTER TABLE exercises ADD COLUMN trainer_id bigint REFERENCES trainer_profiles(id);
CREATE INDEX idx_exercises_trainer_id ON exercises (trainer_id);

ALTER TABLE workout_exercises ADD COLUMN removed_at timestamp(6) without time zone;
