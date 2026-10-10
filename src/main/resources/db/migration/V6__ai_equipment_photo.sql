-- V6: foto do aparelho no assistente de IA. So o texto e guardado (a imagem nunca vai para o banco).
-- kind separa a conversa comum da analise de foto; na analise o corpo da resposta e o JSON estruturado.

ALTER TABLE ai_messages
    ADD COLUMN kind varchar(32) NOT NULL DEFAULT 'TEXT'
        CHECK (kind IN ('TEXT', 'EQUIPMENT_PHOTO'));
