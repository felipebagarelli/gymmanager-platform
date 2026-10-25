-- V19: link de convite do plano (Fase F5). O aluno novo cria a propria conta e vira aluno do personal
-- assinando o plano pelo link. O codigo e aleatorio, nao identifica ninguem e pode ser trocado (o antigo
-- deixa de funcionar).

ALTER TABLE plans ADD COLUMN invite_code varchar(24);
CREATE UNIQUE INDEX uq_plans_invite_code ON plans (invite_code) WHERE invite_code IS NOT NULL;
