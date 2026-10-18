-- V14: ajustes de treino propostos pela IA (D4): progressao e troca de exercicio num treino que o
-- aluno ja faz. Mesmo fluxo e mesma auditoria das propostas de treino novo.

ALTER TABLE ai_workout_proposals ADD COLUMN kind varchar(16) NOT NULL DEFAULT 'NEW_WORKOUTS'
    CHECK (kind IN ('NEW_WORKOUTS', 'ADJUSTMENT'));
ALTER TABLE ai_workout_proposals ADD COLUMN target_workout_id bigint REFERENCES workout(id);
