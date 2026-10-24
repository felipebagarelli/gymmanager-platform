-- V16: direitos do titular e seguranca de sessao.
--   * users.password_changed_at: tokens emitidos antes da troca de senha (ou da exclusao) deixam de valer.
--   * e-mails em minusculas (o login passa a comparar sem diferenciar). Se ja existir outra conta com o
--     mesmo e-mail em minusculas, a antiga fica como esta (o login continua funcionando sem diferenciar).
--   * student_profiles.share_health_with_trainer: o aluno escolhe mostrar ao personal a triagem e o perfil de treino.
--   * Desativar aluno passa a encerrar o vinculo (o aluno volta ao plano gratis): quem estava desativado
--     pelo jeito antigo vira vinculo encerrado com a conta ativa.

ALTER TABLE users ADD COLUMN password_changed_at timestamp(6) without time zone;

UPDATE users u SET email = lower(trim(u.email))
 WHERE u.email <> lower(trim(u.email))
   AND NOT EXISTS (SELECT 1 FROM users x WHERE x.id <> u.id AND x.email = lower(trim(u.email)));

ALTER TABLE student_profiles ADD COLUMN share_health_with_trainer boolean NOT NULL DEFAULT false;

UPDATE trainer_students SET status = 'CANCELED'
 WHERE student_id IN (SELECT id FROM student_profiles WHERE active = false)
   AND status IN ('ACTIVE', 'PAUSED');
UPDATE student_profiles SET active = true WHERE active = false;
