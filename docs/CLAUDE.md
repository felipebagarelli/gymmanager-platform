# CLAUDE.md — GymManager / Plataforma para Personais

Este arquivo contém as regras operacionais para o Claude Code. A especificação detalhada do produto e da arquitetura está em `docs/ARQUITETURA-E-SISTEMA.md`.

## 1. Missão

Evoluir o GymManager atual para uma plataforma de personal trainers e alunos, preservando o que já funciona e evoluindo gradualmente para:

- painel Web React/TypeScript para personais e administração;
- aplicativo Flutter/Dart em Android e iOS, **um só app para aluno e personal** (o papel define o modo);
- API Java/Spring Boot;
- PostgreSQL;
- autenticação e autorização;
- treinos e execução;
- chat personal/aluno;
- assistente de IA contextualizado, que no futuro propõe treinos com confirmação do usuário;
- cadastro aberto (aluno independente, com plano da plataforma) e, depois, hub de personais;
- assinaturas, pagamentos, comissão e repasse;
- notificações;
- testes, Docker, CI/CD e cloud.

## 2. Decisões fixas

- Não recomeçar do zero.
- Reaproveitar o backend e frontend existentes sempre que possível.
- Backend: Java + Spring Boot + PostgreSQL.
- Web: React + TypeScript.
- Mobile: Flutter + Dart.
- Backend: monólito modular.
- Não usar microsserviços nesta fase.
- Não usar Kubernetes nesta fase.
- Não adicionar Kafka/RabbitMQ sem requisito real.
- Não acessar PostgreSQL diretamente do React ou Flutter.
- Regras de negócio ficam no backend.

## 3. Domínios planejados

- auth/identity
- trainer
- student
- exercise
- workout
- billing
- ai
- notification
- social (futuro: grupos, desafios, ranking)
- admin
- common

## 4. Identidade

Separar conta de autenticação e perfil de negócio.

Conceito:

```text
User
├── TrainerProfile
└── StudentProfile
```

Papéis iniciais:

- PLATFORM_ADMIN
- TRAINER
- STUDENT

Um personal só acessa alunos vinculados a ele. Não confiar apenas no ID enviado pela URL.

Planejado (Fase C do `docs/ROADMAP.md`): cadastro aberto de alunos. Um aluno pode existir sem personal (aluno independente).

## 5. Segurança

Planejamento:

- Spring Security;
- password hashing;
- JWT;
- autenticação;
- autorização por role e por vínculo;
- secrets fora do Git;
- endpoints protegidos;
- validação de claims;
- tratamento adequado de 401/403.

O Spring Security possui suporte a JWT como Resource Server. A implementação do projeto deve seguir a documentação oficial e evitar bibliotecas JWT redundantes.

## 6. Treinos

Não colocar séries/repetições na entidade global de exercício.

Preferir:

```text
Exercise
WorkoutPlan
WorkoutPlanExercise
WorkoutAssignment
WorkoutSession
ExercisePerformance
```

O plano representa o planejado; a sessão representa o executado.

A agenda (dias da semana ou esquema rotativo, Fase F) fica na atribuição/rotina do aluno, nunca no treino nem no exercício: o mesmo treino pode cair em dias diferentes para alunos diferentes. Pastas de treino são só organização do personal.

## 7. IA

A IA deve ser um módulo isolado e substituível.

Hoje a IA é somente leitura: explica, sugere e analisa foto de aparelho. Isso vale até a Fase D do `docs/ROADMAP.md`.

Decisão de 13/10/2026: a IA poderá **propor** criação e ajuste de treino, mas **nunca grava sem confirmação explícita do dono do treino**. Treinos criados por personal não são alterados pela IA. Limites (catálogo fechado, volume, progressão) ficam no backend. Triagem de saúde, avisos, termos aceitos, auditoria e LGPD são pré-requisitos (`docs/ARQUITETURA-E-SISTEMA.md`, seções 23 e 47).

A IA pode explicar e sugerir, mas deve respeitar os limites definidos no documento de arquitetura.

Nunca enviar para a IA dados de outros usuários ou secrets.

## 8. Billing

O sistema terá dois modelos de assinatura:

- plano do personal, com comissão da plataforma e repasse (implementado, Stripe Connect);
- plano da plataforma para o aluno independente, sem comissão e sem repasse (planejado, Fase C; decidir antes gateway atual × compras dentro do app das lojas).

Abstrair o provedor:

```text
PaymentGateway
```

Regras importantes:

- webhook validado;
- idempotência;
- histórico financeiro;
- comissão registrada no evento;
- estorno/chargeback tratado;
- pagamento nunca confirmado apenas pelo frontend.

Não implementar cobrança real sem sandbox e validação do fluxo.

## 9. Flutter

Criar `mobile/` separado do `frontend/`.

O app é único para aluno e personal: o papel do usuário autenticado define a navegação. As telas do personal ficam em features próprias, reaproveitando o núcleo (`core/`), sem duplicar regras de negócio, que continuam no backend.

Arquitetura sugerida:

```text
mobile/lib/
├── core/
└── features/
    ├── auth/
    ├── home/
    ├── workouts/
    ├── progress/
    ├── chat/
    ├── ai/
    ├── billing/
    └── profile/
```

Não colocar requests HTTP diretamente em widgets.

## 10. Web

Continuar usando React + TypeScript para o painel do personal/admin. O personal também terá o modo personal no app; manter os dois com as mesmas funções.

Preservar React Router e componentes existentes.

Não reescrever o frontend inteiro apenas para reorganizar pastas.

## 11. Exceções e validação

Usar `@RestControllerAdvice` e padrão de erro consistente.

Principais códigos:

- 400
- 401
- 403
- 404
- 409
- 500

Usar Bean Validation nos DTOs.

## 12. Banco

PostgreSQL.

Evoluir de `ddl-auto=update` para Flyway antes de produção.

Não executar migrations destrutivas sem análise de dados e confirmação.

## 13. Testes

Prioridade:

1. unitários de services;
2. segurança;
3. regras de negócio;
4. integração;
5. Testcontainers para PostgreSQL.

Não buscar cobertura artificial de 100%.

## 14. Processo obrigatório para alterações grandes

Antes de implementar:

1. ler o código relacionado;
2. explicar o impacto;
3. listar arquivos a alterar/criar;
4. identificar breaking changes;
5. propor etapas;
6. implementar somente a etapa autorizada;
7. rodar build/testes;
8. revisar diff;
9. reportar resultado.

Não executar toda uma migração de produto de uma vez.

## 15. Proibições

- Não apagar funcionalidades existentes.
- Não trocar Java/Spring/PostgreSQL sem autorização.
- Não trocar React web sem autorização.
- Não substituir Flutter por outra solução sem autorização.
- Não criar microsserviços agora.
- Não adicionar Kubernetes agora.
- Não colocar API keys/secrets no código.
- Não expor passwordHash.
- Não deixar IA acessar dados indiscriminadamente.
- Não deixar a IA gravar dados sem confirmação explícita do usuário dono do dado.
- Não permitir que frontend decida autorização.
- Não criar pagamento real sem sandbox/testes.
- Não inventar regras de negócio silenciosamente.

## 16. Critério de pronto

Uma feature importante deve, quando aplicável, possuir:

- regra de negócio;
- validação;
- autorização;
- DTOs;
- exceptions;
- testes relevantes;
- integração frontend/mobile;
- tratamento de loading/erro;
- logs seguros;
- build passando;
- documentação mínima.

## 17. Fonte de verdade

Antes de tomar decisões de arquitetura, consultar:

`docs/ARQUITETURA-E-SISTEMA.md`

Plano em fases, status atual e decisões pendentes:

`docs/ROADMAP.md`

Se a documentação não definir uma decisão, não inventar uma arquitetura complexa. Apresentar opções e pedir confirmação antes de implementar mudanças estruturais.
