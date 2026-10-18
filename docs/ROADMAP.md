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

**Backend (Spring Boot + PostgreSQL, Flyway V1 a V7)**
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
  - [x] B2.1. Evolução do aluno no perfil: o personal abre o mesmo Histórico do aluno (calendário, sessões, cargas por exercício, volume semanal e recordes), pelos atalhos "Evolução" e "Calendário". *(16/10/2026)*
  - [x] B2.2. Reativar aluno desativado e pausar/retomar o acompanhamento (selo e filtro "Em pausa"). Backend: `POST /api/v1/students/{id}/reactivate` e `PUT /api/v1/students/{id}/link-status` (só ACTIVE ↔ PAUSED). Pausado, o chat fecha e o aluno não assina planos novos. *(16/10/2026)*
- [x] B3. Mensagens: lista de conversas com todos os alunos (prévia, horário, não lidas, conversa encerrada), contador na aba, a conversa (mesma tela do aluno, do lado do personal) e atalho "Enviar mensagem" no perfil do aluno. Sem mudança no backend. *(15/10/2026)*
- [x] B4. Treinos: lista de treinos (exercícios e alunos de cada um), novo treino já abrindo o editor, editor no celular (adicionar da biblioteca ou criar exercício na hora, séries/repetições/descanso/carga/observação, arrastar para ordenar, retirar), renomear, duplicar, excluir, atribuir a vários alunos e retirar; biblioteca de exercícios (catálogo + os do personal); "Atribuir" no perfil do aluno. *(15/10/2026)*
  - Backend (V7): exercício passou a ter dono (`exercises.trainer_id`; os que já existiam viraram catálogo comum, só leitura). Antes qualquer personal editava ou apagava exercícios de todos. Exercício em uso não pode ser excluído (409). Retirar do treino um exercício que já tem séries registradas só o marca como retirado (`workout_exercises.removed_at`), sem quebrar o histórico. Novos: `GET /workouts/{id}/assignments`, `POST /workouts/{id}/duplicate`, `PUT /workout-exercises/workout/{id}/order`. Respostas ganharam `exerciseCount`/`studentCount` (treino), `exerciseName`/`muscleGroup` (plano), `trainerId` (exercício) e `studentName` (atribuição).
- [x] B5. Planos e cobrança: situação do recebimento (configurar/continuar o cadastro no Stripe pelo navegador, conferido de novo ao voltar para o app), receita mensal em dia e contagem de assinaturas em dia/em atraso/canceladas, planos (criar, editar valor e descrição, desativar para novos alunos) com número de assinantes, e lista de assinaturas por aluno com filtro e atalho para o perfil. Sem mudança no backend. Com isso as 5 abas do personal estão prontas. *(15/10/2026)*
- [ ] B6. Painel web: incluir o que falta (meta semanal, "Como foi?", aluno em atraso; biblioteca com catálogo × exercícios do personal, duplicar e reordenar treino; planos e assinaturas como no app), para os dois produtos ficarem iguais. **Adiado (15/10/2026):** o foco é o app; até lá, editar exercício do catálogo pelo painel responde 403.

### Fase C — Cadastro aberto e aluno independente
Objetivo: qualquer pessoa usa o app sem personal, pagando o plano da plataforma.
- [x] C1. Cadastro de aluno pelo app (`POST /api/v1/auth/register-student`), confirmação de e-mail por código de 6 números (30 min, 5 tentativas, só o hash no banco) e "esqueci a senha" por código. Login com conta pendente leva ao passo que falta. E-mail atrás da porta `EmailSender` (SMTP do fornecedor; sem `MAIL_HOST`, só no log). Migração V8. *(16/10/2026)*
- [x] C2. Aceite registrado em `legal_acceptances` (termos, privacidade e dados de saúde separados; versão, data, IP e aparelho). Idade mínima 12 anos; de 12 a 17, o responsável recebe um link e autoriza numa página do servidor (`/consent/guardian`), e só então a conta entra. *(16/10/2026)*
- [x] C3. Onboarding do aluno sem personal, logo depois de entrar: objetivo, nível, dias por semana, tempo por treino, onde treina (academia, casa com equipamento, peso do corpo) e medidas opcionais. Revisável pelo Perfil. Backend: `GET /api/v1/students/me/onboarding` e `PUT /api/v1/students/me/training-profile` (V9). *(18/10/2026)*
- [x] C4. Triagem de saúde com 7 perguntas sim/não (texto próprio, inspirado no PAR-Q+), guardada com versão e histórico (`POST /api/v1/students/me/health-screening`). Qualquer "sim" marca risco: o app recomenda avaliação médica/profissional e `aiWorkoutsAllowed` fica falso (a Fase D não gera treino). *(18/10/2026)*
- [x] C5. Plano da plataforma (GymManager Pro): grátis (registrar treinos + 1 treino gerado pela IA/mês) ou Pro R$ 19,90/mês ou R$ 149,90/ano, com 7 dias de teste só na primeira assinatura. Checkout do Stripe na conta da plataforma (sem Connect), webhook próprio (`/api/v1/billing/platform-webhook`), cancelar no fim do período, desfazer o cancelamento e pagar a fatura em atraso. Só aluno sem personal e maior de 18. App: cartão no Perfil. Tabela `platform_subscriptions` (V10). **Vendas fechadas por padrão** (`PLATFORM_PLAN_ENABLED=false`) até a Fase D entregar a IA que monta treinos. *(18/10/2026)*
- [x] C6. Modo independente: o aluno sem personal **monta os próprios treinos** (mesmo editor do personal, só com o catálogo; "Monte seu primeiro treino", "Montar novo treino" e editar pelo detalhe do treino). Treinos e Histórico funcionam igual; Mensagens vira "Encontre um personal" (Fase E); Perfil mostra o plano da plataforma. Backend: `workout.student_owner_id` (V11); o dono do treino é o personal ou o próprio aluno; excluir um treino já usado só o tira da lista (o histórico continua). *(18/10/2026)*

### Fase D — IA que propõe treinos (com confirmação)
Objetivo: a IA monta o treino do aluno independente e propõe ajustes; o usuário sempre confirma.
- [x] D1. Proposta estruturada guardada em `ai_workout_proposals` (V13): treinos A/B/C com exercícios pelo código do catálogo; nada vira treino antes do aceite. *(18/10/2026)*
- [x] D2. Geração restrita e **conferida no servidor** (`ProposalRules`/`ProposalParser`): só o catálogo compatível com o equipamento do aluno, exercício desconhecido/duplicado descartado, séries/repetições/descanso trazidos para os limites do nível e do tempo, sem carga sugerida, textos limpos (sem links); pedido sobre dor/lesão/condição médica é recusado. *(18/10/2026)*
- [x] D3. Tela "Treino pela IA": preferência opcional, prévia com aviso fixo, "Usar este treino" (cria os treinos do aluno, ativos), "Gerar outra" e "Descartar". Atalhos na aba Treinos do aluno sem personal. *(18/10/2026)*
- [x] D4. Ajustes num treino que o aluno já faz ("Ajustar com a IA" no detalhe do treino): a IA vê as últimas 4 sessões (carga, repetições, "Como foi?") e propõe progressão ou troca; o servidor limita (carga no máximo +10% e só com 2+ sessões e última não "difícil", séries ±1, troca só do mesmo grupo e do equipamento do aluno, até 3 trocas); prévia "antes → depois"; aplicar confere que o plano não mudou e mantém o histórico do exercício trocado. V14. *(18/10/2026)*
- [x] D5. Auditoria (pedido, proposta validada, aceite/recusa/expiração com data, treinos criados, tokens) e limites: grátis 1 proposta/mês, Pro 30/mês (`AI_PROPOSALS_*`); propostas valem 7 dias. *(18/10/2026)*
- [x] D6. Testes automáticos: exercícios inventados ou de outro equipamento, números fora dos limites, recusa de pedido médico, links e caracteres de controle, preferência do aluno como dado delimitado, proposta de outro aluno, aceite duplicado, aluno que ganhou personal. Falta o teste com o modelo real (ver seção 8). *(18/10/2026)*

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
| 1 | Preço, período grátis e limites do plano da plataforma | C | **Decidido (16/10/2026): grátis (registrar treinos + 1 treino gerado) e pago a R$ 19,90/mês ou R$ 149,90/ano, com 7 dias de teste.** Base da pesquisa: Apps para personal no Brasil cobram do personal de ~R$ 10 a R$ 150/mês (MFIT, Treino Mestre, Nexur, O Personal Digital); apps de treino com IA lá fora vão de US$ 3 a 16/mês (Hevy, Freeletics, Fitbod). Proposta: plano grátis (registrar treinos + 1 treino gerado) e pago perto de R$ 19,90/mês ou R$ 149,90/ano, com 7 dias de teste |
| 2 | Cobrança do plano da plataforma: Stripe ou compras dentro do app (Apple/Google) | C | **Decidido (16/10/2026): começar tudo pelo Stripe; integrar as lojas depois.** Atenção: no Brasil a Apple passou a aceitar pagamento externo (acordo com o CADE, iOS 26.5, 18/06/2026), mas cobra comissão também nesse caso e a opção da Apple aparece ao lado; menores de 18 exigem "parental gate". O Google está mudando as regras (taxas do Brasil não divulgadas). Conferir as regras das duas lojas antes de publicar |
| 3 | Aluno **com** personal pode pedir treino à IA? | D | **Aplicado como proposto (18/10/2026): não.** Só o aluno sem personal pede proposta. "A IA sugere e o personal aprova" fica para depois |
| 4 | Quem é o "dono" do treino gerado pela IA | D | **Resolvido no C6 (18/10/2026):** o treino pode ser do personal ou do próprio aluno sem personal (`student_owner_id`). A IA propõe para esse dono, que confirma antes de gravar |
| 5 | Verificação de e-mail e recuperação de senha | C | **Decidido (16/10/2026): fluxo padrão** (link/código por e-mail, com validade e uso único). Envio por serviço de e-mail transacional (ex.: Brevo, Resend ou Amazon SES) atrás de uma porta `EmailSender`, como o `PaymentProvider`. Exige domínio próprio com SPF/DKIM/DMARC |
| 6 | Idade mínima de uso | C | **Decidido (16/10/2026): a partir de 12 anos, com aceite de termos.** De 12 a 17: consentimento e vínculo de um responsável (LGPD art. 14 e ECA Digital, Lei 15.211/2025, em vigor desde 17/03/2026, que veda autodeclaração de idade e prevê conta vinculada ao responsável até 16 anos). Pagamento e treino por IA de menor só com aprovação do responsável. Validar com advogado antes do lançamento |
| 7 | Comissão da plataforma no hub e regras de cancelamento/reembolso | E | |
| 8 | O que do perfil do personal é público e como funcionam avaliações | E | |

---

## 7. Como trabalhar cada etapa

1. Ler o código relacionado e este roadmap.
2. Propor a etapa: arquivos afetados, mudanças de contrato, migrações, riscos.
3. Implementar só a etapa autorizada, com testes.
4. Rodar build e testes (backend e app); conferir no emulador quando houver tela.
5. Revisar o diff, commitar e marcar a etapa aqui.
6. Anotar na seção 8 o que ficou de fora da etapa (melhorias e limitações conhecidas).

---

## 8. O que falta: melhorias anotadas por etapa

Itens que ficaram de fora de propósito, para atualizações futuras. Ao fazer um deles, mover para a etapa em que entrou.

### B2 — Alunos
- Reenviar acesso / redefinir a senha provisória do aluno (hoje a senha só é definida no cadastro).
- **Pausa não pausa a cobrança:** a mensalidade no Stripe continua; avaliar pausar a cobrança junto (`pause_collection` do Stripe) e data de retorno automática.
- **Desativar só fecha o chat:** o aluno desativado ainda entra no app e vê os treinos. Decidir se deve bloquear o acesso (e o que acontece com a assinatura).
- Evolução: exercícios retirados do plano somem dos gráficos (o nome vem do plano atual). Dá para buscar o nome pelo item retirado (`GET /workout-exercises/{id}` ainda devolve).
- Medidas corporais ao longo do tempo (peso, circunferências, fotos de progresso).

### B3 — Mensagens
- Anexo de foto no chat (o backend só tem texto).
- Notificação push de mensagem nova (hoje o app consulta de tempos em tempos e só enquanto está aberto).
- Busca e filtro na lista de conversas (por nome, só não lidas) quando houver muitos alunos.

### B4 — Treinos
- **Arquivar treino:** hoje só dá para excluir treino que nunca foi atribuído; os antigos ficam na lista para sempre.
- **Catálogo comum:** é só leitura e não tem tela de manutenção (administração da plataforma). Falta um catálogo inicial padronizado (nomes, grupos, equipamento) carregado por migração.
- **Exercício mais completo:** descrição/instruções, vídeo ou imagem, equipamento, exercício por tempo (ex.: prancha 30 s; hoje repetição é número inteiro obrigatório).
- **Plano mais rico:** faixa de repetições ("8–12"), séries diferentes entre si (pirâmide, drop-set), bi-set/supersérie, cadência.
- **Organização:** descrição/objetivo do treino, divisão por dias da semana (A/B/C), validade e data de troca do treino.
- Aviso ao aluno (push) quando recebe treino novo ou o treino muda.
- Se o personal retirar um exercício durante uma sessão em andamento do aluno, o servidor ainda aceita séries dele naquela sessão (avaliar se deve bloquear).
- A lista de treinos faz 2 contagens por treino (bom para o volume atual; trocar por consulta agregada se crescer).
- Painel web (entra no B6): mostrar catálogo × exercícios do personal (editar catálogo agora responde 403), usar duplicar e reordenar, e o nome do exercício que já vem no plano.

### B5 — Planos e cobrança
- **Histórico de pagamentos:** o backend guarda só a assinatura (situação e fim do período), não cada cobrança. Falta registrar as faturas pelo webhook (paga, falhou, valor, data) e mostrar por aluno e por mês.
- **Valor líquido:** a receita mostrada é bruta; falta descontar a taxa do Stripe e a comissão da plataforma.
- **Volta do cadastro no Stripe:** o retorno aponta para o painel web (`/pagamentos`). No app falta um link de volta direto (deep link); hoje a situação é conferida quando o personal volta para o app.
- **Acesso ao painel do Stripe** (saldo, saques) pelo app: link de login do Stripe Express.
- O personal não consegue cancelar a assinatura de um aluno, dar desconto/isenção ou fazer cobrança avulsa.
- **Aluno em atraso:** atalho "cobrar" (mensagem pronta no chat) e lembrete automático antes do vencimento.
- Só existe plano mensal: faltam trimestral/anual e período de teste.
- Formas de pagamento: hoje só cartão (avaliar boleto/Pix no Stripe Brasil).
- Relatório mensal / exportar (CSV) para o personal.

### C1/C2 — Cadastro aberto e aceites
- **Verificação de idade:** hoje a idade é a data de nascimento informada. O ECA Digital veda confiar só na autodeclaração: avaliar o "sinal de idade" das lojas (Apple/Google) ou um provedor de verificação.
- **Conta do responsável:** hoje ele só autoriza por e-mail. Faltam conta vinculada, controles (aprovar compras, ver uso) e revogar a autorização.
- **Documentos:** a versão dos termos é "rascunho" e as URLs estão vazias (o app mostra "Documento em preparação"). Escrever Termos e Política de privacidade e validar com advogado (ver Fase A).
- **E-mail em produção:** domínio próprio, SPF/DKIM/DMARC e `MAIL_HOST` configurado. Em produção, impedir subir sem SMTP (hoje cai para o log).
- Trocar a senha não encerra as sessões já abertas (o token vale até expirar).
- Proteção contra cadastro em massa (limite por IP, CAPTCHA). Hoje só há intervalo de 1 minuto entre reenvios por conta.
- Contas criadas pelo personal ou pelo cadastro de personal do painel entram como já confirmadas (sem código).
- Página de autorização do responsável é simples (sem a identidade visual do app).
- O login compara o e-mail exatamente como foi salvo: o cadastro novo salva em minúsculas, mas contas antigas com maiúsculas exigem digitar igual. Padronizar (migrar e-mails para minúsculas e comparar sem diferenciar).

### C3/C4 — Onboarding e triagem de saúde
- **Validar a triagem** com profissional de saúde/educação física. O texto é próprio, inspirado no PAR-Q+ (o questionário oficial tem licença própria: não copiar sem autorização).
- **Validade da triagem:** pedir para responder de novo periodicamente (ex.: a cada 12 meses) e quando o aluno informar mudança de saúde.
- **Liberação médica:** quem respondeu "sim" só volta a ter treino automático respondendo de novo; avaliar registrar a liberação (data, profissional) em vez de confiar só na nova resposta.
- Lesões e exercícios a evitar não são perguntados (a IA da Fase D vai precisar disso).
- Aluno com personal não faz onboarding nem triagem pelo app; o personal também não vê essas respostas. Decidir se o personal deve ver (com consentimento do aluno).
- No Perfil, revisar reabre todos os passos (não dá para editar só um item).

### C5 — Plano da plataforma
- **Abrir as vendas só com a Fase D pronta:** hoje o Pro não libera nada a mais. Ligar `PLATFORM_PLAN_ENABLED` junto com a IA que monta treinos.
- **Contador do grátis:** o limite de 1 treino gerado por mês ainda não é contado (nasce com a Fase D).
- **Menores de 18:** assinatura bloqueada; falta o fluxo de aprovação do responsável na compra (ECA Digital; a Apple também exige "parental gate").
- **Trocar cartão e mudar de mensal para anual:** usar o Portal do Cliente do Stripe (hoje não há como pelo app).
- **Direito de arrependimento (CDC, 7 dias)** e política de reembolso por escrito nos termos.
- Nota fiscal/impostos da receita da plataforma.
- Lojas (Apple/Google): integrar depois, como decidido; conferir as regras antes de publicar com cobrança.

### C6 — Modo independente
- ~~Catálogo inicial de exercícios~~ **feito (V12, 18/10/2026):** 91 exercícios com grupo muscular, equipamento principal e código estável (`catalog_code`, usado pela IA). Falta: descrição/vídeo, "precisa de banco", exercício por tempo de verdade (hoje "(segundos)"/"(minutos)" no nome) e filtro por equipamento na escolha do aluno.
- **Ligar um aluno que já tem conta a um personal:** hoje o personal cadastra com e-mail novo; com e-mail já usado dá "e-mail em uso". Falta convite/aceite (base da Fase E). Decidir o que acontece com os treinos próprios quando ele ganha um personal (hoje continuam ativos).
- O aluno sem personal não cria exercícios próprios nem edita nome/telefone pelo app.
- Textos do Personal IA ainda falam em "seu personal" em alguns pontos; revisar para quem treina sozinho.

### Fase D — IA que propõe treinos
- **D4:** feito. Falta: lembrete automático de "hora de progredir" (hoje o aluno pede), e usar o histórico de mais de um treino (hoje olha só o treino escolhido).
- **Testar com a chave real** (`AI_API_KEY`): qualidade das propostas, tempo de resposta, custo por proposta e conferir o `AI_MODEL` (o padrão `claude-opus-5` não foi confirmado). Fazer uma rodada de "red team" com o modelo real (pedidos médicos, tentativas de mudar as regras).
- **Abrir as vendas do Pro:** agora o Pro já entrega mais (30 propostas/mês contra 1 no grátis). Ligar `PLATFORM_PLAN_ENABLED` é decisão de negócio.
- Menores de 18: proposta bloqueada até existir a aprovação do responsável.
- Aluno com personal: a IA não propõe; falta "a IA sugere e o personal aprova" (decisão 3).
- Banco: exercícios com halteres/barra que precisam de banco entram mesmo para quem não marcou "banco" (o catálogo não tem esse dado).
- Painel de custo da IA (tokens por proposta já ficam gravados).
- Itens marcados no ROADMAP como obrigatórios antes de ir ao ar (seção 5) que ainda faltam: triagem refeita periodicamente, termos/política revisados por advogado, exclusão e retificação de dados pelo app.
