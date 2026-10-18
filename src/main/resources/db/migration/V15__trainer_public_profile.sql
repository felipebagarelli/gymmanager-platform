-- V15: perfil publico do personal no hub (Fase E). So aparece quem escolheu ("listed"), tem plano
-- ativo e recebimento habilitado. E-mail e telefone nunca sao publicos.

ALTER TABLE trainer_profiles ADD COLUMN listed boolean NOT NULL DEFAULT false;
ALTER TABLE trainer_profiles ADD COLUMN headline varchar(120);
ALTER TABLE trainer_profiles ADD COLUMN city varchar(80);
ALTER TABLE trainer_profiles ADD COLUMN state varchar(2);
ALTER TABLE trainer_profiles ADD COLUMN online boolean NOT NULL DEFAULT true;
ALTER TABLE trainer_profiles ADD COLUMN in_person boolean NOT NULL DEFAULT false;
ALTER TABLE trainer_profiles ADD COLUMN specialties varchar(255);
CREATE INDEX idx_trainer_profiles_listed ON trainer_profiles (listed);
