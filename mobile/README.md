# GymManager Mobile (aluno)

App Flutter do aluno: ver os treinos atribuídos, executar (registrar séries) e consultar o histórico.
Fala com a API Spring Boot do repositório (`/api/v1/...`). Só contas com role `STUDENT` entram;
contas de personal usam o painel web.

## Estrutura

```
lib/
├── core/            config, rede (Dio + interceptor de auth), token seguro, rotas, tema
└── features/
    ├── auth/        login, sessão, perfil (GET /api/v1/students/me)
    ├── workouts/    meus treinos e exercícios de cada treino
    ├── sessions/    execução do treino (sessão, séries) e histórico
    ├── chat/        conversa com o personal (polling 3s aberta / 10s contador)
    ├── assistant/   assistente de IA (privado do aluno; limite diário; aviso de que não substitui o personal)
    ├── profile/     perfil e sair
    └── home/        abas: Treinos / Histórico / Mensagens / Assistente / Perfil
```

Estado com Riverpod; cada feature separa `data` (API), `domain` (modelos), `application`
(controllers/providers) e `presentation` (telas). Widgets não fazem requisições.

O JWT fica em `flutter_secure_storage`. Um 401 em qualquer chamada limpa o token e volta ao login.

## Rodar

Pré-requisitos: Flutter (canal stable) e a API no ar (`./mvnw spring-boot:run`, com `JWT_SECRET`,
`DB_USERNAME` e `DB_PASSWORD` no ambiente).

```bash
flutter pub get
flutter run -d chrome --web-port 5174
```

- O CORS da API aceita `http://localhost:5173` (painel) e `http://localhost:5174` (este app) por padrão;
  para outras origens use `CORS_ALLOWED_ORIGINS` (lista separada por vírgula) no backend.
- Outro endereço de API: `--dart-define=API_BASE_URL=http://host:8080`
  (emulador Android: `http://10.0.2.2:8080`).

## Testes

```bash
flutter analyze
flutter test
```

Testes de contrato contra a API **real** (desligados por padrão; criam e finalizam uma sessão de treino
para o aluno informado):

```bash
flutter test test/integration/api_contract_test.dart \
  --dart-define=RUN_API_TESTS=true \
  --dart-define=API_EMAIL=aluno@exemplo.com \
  --dart-define=API_PASSWORD=... \
  --dart-define=API_TRAINER_EMAIL=personal@exemplo.com
```

## Assistente de IA

Aba "Assistente" (`/api/v1/ai/*`, somente aluno). Sem `AI_API_KEY` no backend, o app mostra
"O assistente não está disponível no momento." Para ativar: definir `AI_API_KEY` (e opcionalmente
`AI_MODEL`, `AI_DAILY_LIMIT`) no ambiente do backend — nunca commitar a chave.
