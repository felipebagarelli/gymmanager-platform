-- V12: catalogo inicial de exercicios (comum a todos, somente leitura pela API).
--   * equipment: equipamento principal, para filtrar pelo que o aluno tem (e para a IA da Fase D).
--   * catalog_code: codigo estavel do exercicio do catalogo; e por ele que a IA se refere ao exercicio.
-- Exercicio do catalogo que ja existia com o mesmo nome e completado, em vez de duplicado.
-- Itens marcados "(segundos)"/"(minutos)": o numero de repeticoes do plano vale como tempo.

ALTER TABLE exercises ADD COLUMN equipment varchar(32)
    CHECK (equipment IN ('BARBELL', 'DUMBBELL', 'MACHINE', 'CABLE', 'BODYWEIGHT', 'KETTLEBELL', 'BAND', 'PULL_UP_BAR'));
ALTER TABLE exercises ADD COLUMN catalog_code varchar(64);
CREATE UNIQUE INDEX uq_exercises_catalog_code ON exercises (catalog_code) WHERE catalog_code IS NOT NULL;

CREATE TEMP TABLE catalog_seed (code varchar(64), name varchar(255), muscle_group varchar(255), equipment varchar(32)) ON COMMIT DROP;
INSERT INTO catalog_seed (code, name, muscle_group, equipment) VALUES
    ('supino_reto_com_barra', 'Supino reto com barra', 'Peito', 'BARBELL'),
    ('supino_inclinado_com_barra', 'Supino inclinado com barra', 'Peito', 'BARBELL'),
    ('supino_reto_com_halteres', 'Supino reto com halteres', 'Peito', 'DUMBBELL'),
    ('supino_inclinado_com_halteres', 'Supino inclinado com halteres', 'Peito', 'DUMBBELL'),
    ('crucifixo_com_halteres', 'Crucifixo com halteres', 'Peito', 'DUMBBELL'),
    ('supino_na_maquina', 'Supino na máquina', 'Peito', 'MACHINE'),
    ('voador_peck_deck', 'Voador (peck deck)', 'Peito', 'MACHINE'),
    ('crossover_no_cabo', 'Crossover no cabo', 'Peito', 'CABLE'),
    ('flexao_de_braco', 'Flexão de braço', 'Peito', 'BODYWEIGHT'),
    ('flexao_de_braco_com_joelhos_apoiados', 'Flexão de braço com joelhos apoiados', 'Peito', 'BODYWEIGHT'),
    ('supino_com_elastico', 'Supino com elástico', 'Peito', 'BAND'),
    ('puxada_frontal_na_polia', 'Puxada frontal na polia', 'Costas', 'CABLE'),
    ('remada_baixa_na_polia', 'Remada baixa na polia', 'Costas', 'CABLE'),
    ('pulldown_com_bracos_estendidos', 'Pulldown com braços estendidos', 'Costas', 'CABLE'),
    ('remada_curvada_com_barra', 'Remada curvada com barra', 'Costas', 'BARBELL'),
    ('levantamento_terra', 'Levantamento terra', 'Costas', 'BARBELL'),
    ('remada_unilateral_com_halter', 'Remada unilateral com halter', 'Costas', 'DUMBBELL'),
    ('remada_na_maquina', 'Remada na máquina', 'Costas', 'MACHINE'),
    ('barra_fixa', 'Barra fixa', 'Costas', 'PULL_UP_BAR'),
    ('barra_fixa_negativa', 'Barra fixa negativa', 'Costas', 'PULL_UP_BAR'),
    ('remada_com_elastico', 'Remada com elástico', 'Costas', 'BAND'),
    ('superman_extensao_lombar_no_chao', 'Superman (extensão lombar no chão)', 'Costas', 'BODYWEIGHT'),
    ('remada_com_kettlebell', 'Remada com kettlebell', 'Costas', 'KETTLEBELL'),
    ('agachamento_livre_com_barra', 'Agachamento livre com barra', 'Pernas', 'BARBELL'),
    ('agachamento_goblet', 'Agachamento goblet', 'Pernas', 'DUMBBELL'),
    ('agachamento_com_peso_do_corpo', 'Agachamento com peso do corpo', 'Pernas', 'BODYWEIGHT'),
    ('agachamento_com_elastico', 'Agachamento com elástico', 'Pernas', 'BAND'),
    ('agachamento_bulgaro', 'Agachamento búlgaro', 'Pernas', 'DUMBBELL'),
    ('afundo_com_halteres', 'Afundo com halteres', 'Pernas', 'DUMBBELL'),
    ('afundo_com_peso_do_corpo', 'Afundo com peso do corpo', 'Pernas', 'BODYWEIGHT'),
    ('leg_press_45', 'Leg press 45°', 'Pernas', 'MACHINE'),
    ('agachamento_no_hack', 'Agachamento no hack', 'Pernas', 'MACHINE'),
    ('cadeira_extensora', 'Cadeira extensora', 'Pernas', 'MACHINE'),
    ('mesa_flexora', 'Mesa flexora', 'Pernas', 'MACHINE'),
    ('cadeira_flexora', 'Cadeira flexora', 'Pernas', 'MACHINE'),
    ('stiff_com_barra', 'Stiff com barra', 'Pernas', 'BARBELL'),
    ('stiff_com_halteres', 'Stiff com halteres', 'Pernas', 'DUMBBELL'),
    ('agachamento_sumo_com_halter', 'Agachamento sumô com halter', 'Pernas', 'DUMBBELL'),
    ('agachamento_goblet_com_kettlebell', 'Agachamento goblet com kettlebell', 'Pernas', 'KETTLEBELL'),
    ('subida_no_banco_step_up', 'Subida no banco (step-up)', 'Pernas', 'BODYWEIGHT'),
    ('elevacao_pelvica_com_barra', 'Elevação pélvica com barra', 'Glúteos', 'BARBELL'),
    ('elevacao_pelvica_com_peso_do_corpo', 'Elevação pélvica com peso do corpo', 'Glúteos', 'BODYWEIGHT'),
    ('ponte_de_gluteo_unilateral', 'Ponte de glúteo unilateral', 'Glúteos', 'BODYWEIGHT'),
    ('cadeira_abdutora', 'Cadeira abdutora', 'Glúteos', 'MACHINE'),
    ('coice_de_gluteo_no_cabo', 'Coice de glúteo no cabo', 'Glúteos', 'CABLE'),
    ('abducao_de_quadril_com_elastico', 'Abdução de quadril com elástico', 'Glúteos', 'BAND'),
    ('swing_com_kettlebell', 'Swing com kettlebell', 'Glúteos', 'KETTLEBELL'),
    ('desenvolvimento_com_halteres', 'Desenvolvimento com halteres', 'Ombros', 'DUMBBELL'),
    ('desenvolvimento_com_barra', 'Desenvolvimento com barra', 'Ombros', 'BARBELL'),
    ('desenvolvimento_na_maquina', 'Desenvolvimento na máquina', 'Ombros', 'MACHINE'),
    ('elevacao_lateral_com_halteres', 'Elevação lateral com halteres', 'Ombros', 'DUMBBELL'),
    ('elevacao_lateral_no_cabo', 'Elevação lateral no cabo', 'Ombros', 'CABLE'),
    ('elevacao_lateral_com_elastico', 'Elevação lateral com elástico', 'Ombros', 'BAND'),
    ('elevacao_frontal_com_halteres', 'Elevação frontal com halteres', 'Ombros', 'DUMBBELL'),
    ('crucifixo_invertido_com_halteres', 'Crucifixo invertido com halteres', 'Ombros', 'DUMBBELL'),
    ('face_pull_no_cabo', 'Face pull no cabo', 'Ombros', 'CABLE'),
    ('flexao_pike', 'Flexão pike', 'Ombros', 'BODYWEIGHT'),
    ('desenvolvimento_com_kettlebell', 'Desenvolvimento com kettlebell', 'Ombros', 'KETTLEBELL'),
    ('rosca_direta_com_barra', 'Rosca direta com barra', 'Bíceps', 'BARBELL'),
    ('rosca_alternada_com_halteres', 'Rosca alternada com halteres', 'Bíceps', 'DUMBBELL'),
    ('rosca_martelo', 'Rosca martelo', 'Bíceps', 'DUMBBELL'),
    ('rosca_concentrada', 'Rosca concentrada', 'Bíceps', 'DUMBBELL'),
    ('rosca_no_cabo', 'Rosca no cabo', 'Bíceps', 'CABLE'),
    ('rosca_scott_na_maquina', 'Rosca Scott na máquina', 'Bíceps', 'MACHINE'),
    ('rosca_com_elastico', 'Rosca com elástico', 'Bíceps', 'BAND'),
    ('triceps_na_polia_com_corda', 'Tríceps na polia com corda', 'Tríceps', 'CABLE'),
    ('triceps_na_polia_com_barra', 'Tríceps na polia com barra', 'Tríceps', 'CABLE'),
    ('triceps_frances_com_halter', 'Tríceps francês com halter', 'Tríceps', 'DUMBBELL'),
    ('triceps_coice_com_halter', 'Tríceps coice com halter', 'Tríceps', 'DUMBBELL'),
    ('triceps_testa_com_barra', 'Tríceps testa com barra', 'Tríceps', 'BARBELL'),
    ('mergulho_no_banco', 'Mergulho no banco', 'Tríceps', 'BODYWEIGHT'),
    ('flexao_de_braco_fechada', 'Flexão de braço fechada', 'Tríceps', 'BODYWEIGHT'),
    ('triceps_com_elastico', 'Tríceps com elástico', 'Tríceps', 'BAND'),
    ('abdominal_supra', 'Abdominal supra', 'Abdômen', 'BODYWEIGHT'),
    ('elevacao_de_pernas_deitado', 'Elevação de pernas deitado', 'Abdômen', 'BODYWEIGHT'),
    ('abdominal_bicicleta', 'Abdominal bicicleta', 'Abdômen', 'BODYWEIGHT'),
    ('dead_bug', 'Dead bug', 'Abdômen', 'BODYWEIGHT'),
    ('prancha_segundos', 'Prancha (segundos)', 'Abdômen', 'BODYWEIGHT'),
    ('prancha_lateral_segundos', 'Prancha lateral (segundos)', 'Abdômen', 'BODYWEIGHT'),
    ('abdominal_na_polia', 'Abdominal na polia', 'Abdômen', 'CABLE'),
    ('elevacao_de_pernas_na_barra', 'Elevação de pernas na barra', 'Abdômen', 'PULL_UP_BAR'),
    ('panturrilha_em_pe_na_maquina', 'Panturrilha em pé na máquina', 'Panturrilha', 'MACHINE'),
    ('panturrilha_sentado_na_maquina', 'Panturrilha sentado na máquina', 'Panturrilha', 'MACHINE'),
    ('panturrilha_em_pe_com_halteres', 'Panturrilha em pé com halteres', 'Panturrilha', 'DUMBBELL'),
    ('panturrilha_unilateral_com_peso_do_corpo', 'Panturrilha unilateral com peso do corpo', 'Panturrilha', 'BODYWEIGHT'),
    ('esteira_minutos', 'Esteira (minutos)', 'Cardio', 'MACHINE'),
    ('bicicleta_ergometrica_minutos', 'Bicicleta ergométrica (minutos)', 'Cardio', 'MACHINE'),
    ('eliptico_minutos', 'Elíptico (minutos)', 'Cardio', 'MACHINE'),
    ('polichinelo', 'Polichinelo', 'Cardio', 'BODYWEIGHT'),
    ('burpee', 'Burpee', 'Cardio', 'BODYWEIGHT'),
    ('escalador_mountain_climber', 'Escalador (mountain climber)', 'Cardio', 'BODYWEIGHT');

UPDATE exercises e
   SET catalog_code = s.code, equipment = s.equipment, muscle_group = s.muscle_group
  FROM catalog_seed s
 WHERE e.id = (SELECT min(x.id) FROM exercises x WHERE x.trainer_id IS NULL AND lower(x.name) = lower(s.name));

INSERT INTO exercises (name, muscle_group, equipment, catalog_code)
SELECT s.name, s.muscle_group, s.equipment, s.code
  FROM catalog_seed s
 WHERE NOT EXISTS (SELECT 1 FROM exercises e WHERE e.catalog_code = s.code);
