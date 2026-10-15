# GymManager — Roadmap e base de trabalho

> **Atualizado em:** 13/10/2026
> **Status:** decisões de produto registradas; **nenhuma implementação desta expansão começou**.
> **Regras de produto e arquitetura:** `docs/ARQUITETURA-E-SISTEMA.md` (fonte de verdade).
> **Regras operacionais para o Claude Code:** `docs/CLAUDE.md`.

Este documento é a base para seguirmos: o que já existe, para onde vamos, em que ordem e o que ainda precisa ser decidido. Cada fase é feita em etapas pequenas e autorizadas uma a uma (ver `docs/CLAUDE.md`, seção 14).

---

## 1. Decisões de produto (13/10/2026)

1. **Um único aplicativo para aluno e personal.** O mesmo app Flutter atende os dois papéis: o login decide o modo (aluno ou personal). Uma só ficha nas lojas. O painel web continua existindo para quem prefere o computador e para a administração da plataforma.
2. **O personal administra tudo pelo celular:** alunos, treinos (montar e atribuir), conversas, planos e cobrança. Paridade com o painel web.
3. **Cadastro aberto.** Qualquer pessoa pode criar conta de aluno pelo app, mesmo sem personal (**aluno independente**). Hoje só o personal cria alunos.
4. **Plano da plataforma.** O aluno independente paga um plano do próprio aplicativo (cobrado pela plataforma, sem personal e sem repasse). Preço e limites a definir.
5. **IA que monta e ajusta treino, sempre com confirmação.** A IA passa a poder **propor** criação e alteração de treino. Nada é gravado sem a **confirmação explícita** do usuário dono do treino. A IA nunca grava sozinha.
6. **Segurança e responsabilidade antes de liberar a IA de treino:** questionário de saúde, limites de geração, prévia e aceite, avisos, termos aceitos e LGPD (detalhes na seção 5).
7. **Futuro: hub de personais.** O aluno poderá buscar e contratar um personal dentro do app. O aluno independente é a porta de entrada para esse hub.

---

## 2. Onde estamos (13/10/2026)

**Backend (Spring Boot + PostgreSQL, Flyway V1 a V6)**
- Autenticação JWT; papéis `TRAINER` e `STUDENT` (há `PLATFORM_ADMIN` previsto, sem telas).
- Personal, aluno e vínculo; exercícios; treinos e atribuição; sessões e séries, com "Como foi?" (`effort`) e meta semanal (`weeklyGoal`, V5).
- Chat personal/aluno (só texto).
- Personal IA: perguntas em texto e **foto do aparelho** com resposta estruturada (V6). A imagem não é guardada. Limite de 30 perguntas/dia. Hoje é **somente leitura**.
- Cobrança: Stripe Connect (plano do personal, assinatura do aluno, webhook idempotente, comissão da plataforma), bloqueio por atraso (402) e link para regularizar a cobrança em aberto.
- Docker, compose de produção e Caddy escritos, mas **nunca executados**. Container com `TZ=America/Sao_Paulo`.

**Painel web do personal (React)**
- Dashboard, alunos, treinos, exercícios, sessões do aluno, chat e pagamentos.
- Ainda **não** mostra: meta semanal, "Como foi?" das séries e aluno em atraso.

**App do aluno (Flutter)**
- Redesenho completo: Treinos, detalhe, execução (série, descanso, concluído), Histórico (calendário e evolução), Mensagens, Personal IA (com foto), Perfil e tela de mensalidade em atraso.
- Revisão de código geral feita e corrigida. ~180 testes no app e ~150 no backend.
- Pronto para build de release (permissão de internet corrigida), mas **sem assinatura de release, nome e ícone finais**.

**Repositório:** o trabalho mais recente está só no computador (pasta `D:`), **ainda não enviado ao GitHub**.

---

## 3. Fases

A ordem evita dependências quebradas. Fases podem ser antecipadas por decisão explícita.

**Decisão de 15/10/2026:** o lançamento (Fase A) fica **por último**; seguimos primeiro com o app do personal (Fase B).

```text
FASE B  App do personal (mesmo app, modo personal)      ← em andamento
   ↓
FASE C  Cadastro aberto + aluno independente + plano da plataforma
   ↓
FASE D  IA que propõe treinos com confirmação
   ↓
FASE E  Hub de personais (buscar e contratar dentro do app)
   ↓
FASE A  Lançamento (lojas, servidor, documentos legais)
```

B e C são independentes entre si e podem ser trocadas de ordem. D depende de C (é o aluno independente que mais precisa dela). E depende de B e C. A pode ser antecipada a qualquer momento (por exemplo, um teste fechado na Google Play), mas fica por último por decisão do produto.

### Fase A — Lançamento (por último)
Objetivo: colocar o app nas mãos de usuários reais (começando por teste fechado).
- [ ] Enviar o repositório ao GitHub (branch + PR do redesenho).
- [ ] Subir o backend em um servidor (seguir `docs/DEPLOY.md`): domínio, HTTPS, banco, backup testado.
- [ ] Validar Stripe em modo teste ponta a ponta (inclui atraso e regularização).
- [ ] Validar o Personal IA com chave real e conferir `AI_MODEL`.
- [ ] Android: chave de assinatura de release, nome e ícone finais, identificador definitivo.
- [ ] Política de privacidade e termos de uso publicados (URL) e ligados ao item "Privacidade e termos" do Perfil.
- [ ] Exclusão de conta pelo app (exigência das lojas): endpoint + tela.
- [ ] Teste fechado na Google Play. iOS depois (exige Mac e conta Apple).

### Fase B — App do personal (modo personal no mesmo app)
Objetivo: o personal faz pelo celular tudo o que faz no painel web. O backend já tem quase todos os endpoints.
- [x] B1. Login multipapel: o app aceita `TRAINER` e abre a navegação do personal (Alunos, Treinos, Mensagens, Planos, Perfil). Perfil do personal pronto; as demais abas mostram "em construção" até as etapas seguintes. *(15/10/2026)*
- [x] B2. Alunos: lista com busca e filtros (ativos, em atraso, inativos), último treino, situação da mensalidade; perfil com dados, números da semana e meta, treinos atribuídos e sessões com o "Como foi?"; cadastrar, editar (inclui meta semanal) e desativar. *(15/10/2026)*
  - Backend: `GET /api/v1/students/{id}` passou a exigir o personal dono do vínculo ou o próprio aluno (antes qualquer usuário logado lia qualquer aluno); resposta ganhou `lastWorkoutAt`; edição aceita `clearWeeklyGoal`.
  - [ ] B2.1. Evolução do aluno no perfil (calendário e gráficos do Histórico, reaproveitados).
  - [ ] B2.2. Reativar aluno desativado (não existe endpoint) e pausar vínculo (`PAUSED` existe no modelo, sem endpoint).
- [ ] B3. Mensagens: lista de conversas com todos os alunos e não lidas.
- [ ] B4. Treinos: biblioteca de exercícios, montar treino no celular (fluxo pensado para tela pequena), duplicar, ordenar, atribuir.
- [ ] B5. Planos e cobrança: criar planos, ver assinaturas e pagamentos, cadastro de recebimento no Stripe (abre no navegador).
- [ ] B6. Painel web: incluir o que falta (meta semanal, "Como foi?", aluno em atraso), para os dois produtos ficarem iguais.

### Fase C — Cadastro aberto e aluno independente
Objetivo: qualquer pessoa usa o app sem personal, pagando o plano da plataforma.
- [ ] C1. Cadastro de aluno pelo app (`register-student`), com verificação de e-mail e recuperação de senha.
- [ ] C2. Aceite de termos e política de privacidade **registrado** (versão + data). Consentimento específico para dados de saúde (LGPD).
- [ ] C3. Onboarding: objetivo, nível, dias por semana, tempo por treino, equipamento disponível.
- [ ] C4. Questionário de saúde (triagem tipo PAR-Q). Resposta de risco bloqueia a geração de treino por IA e recomenda avaliação profissional/médica.
- [ ] C5. Plano da plataforma: assinatura cobrada pela plataforma (sem Connect e sem repasse), com período gratuito/limites a definir. Ver decisão pendente sobre compras dentro do app (seção 6).
- [ ] C6. App no "modo independente": Treinos e Histórico funcionam igual; Mensagens vira a entrada para "encontrar um personal" (Fase E); Perfil mostra o plano da plataforma.

### Fase D — IA que propõe treinos (com confirmação)
Objetivo: a IA monta o treino do aluno independente e propõe ajustes; o usuário sempre confirma.
- [ ] D1. Modelo de **proposta**: a IA gera uma proposta estruturada; nada vai para os treinos até o aceite.
- [ ] D2. Geração restrita: só exercícios do catálogo da plataforma; limites de volume, séries e progressão; carga inicial conservadora; nada de reabilitação, dor ou condição médica.
- [ ] D3. Tela de prévia: o aluno vê o treino proposto, pode recusar ou pedir outro, e só "Usar este treino" grava (pela API normal de treinos).
- [ ] D4. Ajustes propostos pela IA (progressão de carga, troca de exercício) com o mesmo fluxo de prévia e aceite.
- [ ] D5. Auditoria: guardar cada proposta, quem aceitou/recusou e quando. Limites de custo e de uso por plano.
- [ ] D6. Testes de segurança da IA: tentativa de burlar limites, pedidos médicos, dados de terceiros, injeção de instruções.

### Fase E — Hub de personais
Objetivo: o aluno encontra e contrata um personal dentro do app.
- [ ] E1. Perfil público do personal (foto, bio, especialidades, cidade/online, planos e preços), com controle do que é público.
- [ ] E2. Busca e filtros.
- [ ] E3. Contratar: assinar o plano do personal pelo app cria o vínculo (`TrainerStudent` ativo).
- [ ] E4. Transição do aluno independente: o histórico e os treinos feitos com a IA continuam visíveis; o personal passa a ser o dono dos novos treinos.
- [ ] E5. Avaliações e moderação (definir regras antes).

---

## 4. Regras que mudam com a expansão

| Antes | Depois |
|---|---|
| App mobile só do aluno | Mesmo app para aluno e personal (modo pelo papel) |
| Aluno só existe vinculado a um personal | Aluno pode existir sem personal (independente) |
| Só o personal cria alunos | Cadastro aberto pelo app |
| Cobrança só do plano do personal (Connect + comissão) | Também plano da plataforma (cobrança direta da plataforma) |
| IA somente leitura | IA **propõe** criação/alteração de treino; grava só com confirmação explícita do dono do treino |
| Marketplace fora do escopo | Hub de personais planejado (Fase E); marketplace de academias/suplementos continua fora |

O detalhamento de cada regra está em `docs/ARQUITETURA-E-SISTEMA.md`, seção 47.

---

## 5. Segurança e responsabilidade (obrigatório antes da Fase D ir ao ar)

- **Triagem de saúde** antes de gerar treino (tipo PAR-Q), refeita periodicamente. Respostas de risco bloqueiam a geração e orientam procurar profissional/médico.
- **Limites duros no backend** (não só no prompt): catálogo fechado de exercícios, limites de volume e progressão, faixa de repetições e descanso, nada para reabilitação/dor/gestação/condições médicas.
- **Prévia e aceite**: nada é gravado sem o usuário tocar em confirmar. O aceite fica registrado.
- **Avisos fixos**: a IA não substitui personal, médico ou fisioterapeuta; pare o exercício diante de dor, tontura ou mal-estar.
- **Termos de uso e política de privacidade** aceitos e versionados; revisão jurídica antes da operação comercial.
- **LGPD**: dados de saúde são sensíveis; consentimento específico, finalidade definida, mínimo necessário enviado à IA, exclusão e retificação pelo app.
- **Idade mínima** definida (menores exigem consentimento dos responsáveis).
- **Auditoria e custo**: registro de propostas e aceites; limites de uso por plano.

---

## 6. Decisões pendentes (precisam de resposta antes da fase correspondente)

| # | Decisão | Fase | Observação |
|---|---|---|---|
| 1 | Preço, período grátis e limites do plano da plataforma | C | Ex.: grátis com 1 treino gerado/mês × só assinatura |
| 2 | Cobrança do plano da plataforma: Stripe ou compras dentro do app (Apple/Google) | C | As lojas costumam exigir o sistema de pagamento delas para assinaturas digitais usadas no app. Pesquisar antes de implementar |
| 3 | Aluno **com** personal pode pedir treino à IA? | D | Proposta: não. A IA só sugere, e o personal aprova; os treinos do personal não são alterados pela IA |
| 4 | Quem é o "dono" do treino gerado pela IA | D | Hoje todo treino pertence a um personal; o modelo de dados precisa de um dono para o aluno independente |
| 5 | Verificação de e-mail e recuperação de senha | C | Exige envio de e-mail (não existe hoje) |
| 6 | Idade mínima de uso | C | Impacta LGPD e lojas |
| 7 | Comissão da plataforma no hub e regras de cancelamento/reembolso | E | |
| 8 | O que do perfil do personal é público e como funcionam avaliações | E | |

---

## 7. Como trabalhar cada etapa

1. Ler o código relacionado e este roadmap.
2. Propor a etapa: arquivos afetados, mudanças de contrato, migrações, riscos.
3. Implementar só a etapa autorizada, com testes.
4. Rodar build e testes (backend e app); conferir no emulador quando houver tela.
5. Revisar o diff, commitar e marcar a etapa aqui.
