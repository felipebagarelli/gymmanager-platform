# Gym Manager

Aplicação Full Stack para gerenciamento de academia, com API REST em Java e Spring Boot e interface web em React e TypeScript.

O sistema permite gerenciar alunos, exercícios e treinos, incluindo a associação de exercícios a um treino com definição de séries e repetições.

> **Projeto em desenvolvimento**
>
> O Gym Manager evolui conforme novos conhecimentos são incorporados. As funcionalidades listadas representam o estágio atual da aplicação.


---

## Screenshots

### Dashboard

![Dashboard](./docs/images/dashboard.png)

### Alunos

![Lista de alunos](./docs/images/alunos.png)

### Treinos do aluno

![Treinos](./docs/images/treinosalunos.png)

### Exercícios do treino

![Exercícios do treino](./docs/images/exerciciostreino.png)

### Formulário

![Formulário de exercícios do treino](./docs/images/formexerciciosdotreino.png)

---

## Objetivo

O Gym Manager simula um sistema que poderia ser utilizado por academias e personal trainers para gerenciamento de alunos, exercícios e treinos.

O projeto começou pela API em Java e Spring Boot e posteriormente ganhou um frontend em React e TypeScript. Ele é usado como ambiente de aprendizado e prática, evoluindo gradualmente das operações básicas de CRUD até segurança, validação, testes e publicação.

---

## Tecnologias

### Backend

- Java 25
- Spring Boot
- Spring Web
- Spring Data JPA
- Hibernate
- PostgreSQL
- Maven
- Lombok

### Frontend

- React
- TypeScript
- Vite
- React Router
- HTML e CSS
- ESLint

### Ferramentas

- Git e GitHub
- IntelliJ IDEA
- Visual Studio Code

---

## Arquitetura

O backend segue uma arquitetura em camadas:

```text
Controller
    ↓
Service
    ↓
Repository
    ↓
PostgreSQL
```

A aplicação está organizada em Controllers, Services, Repositories, Entities e DTOs, com objetos separados para requisição e resposta.

O frontend utiliza React com componentes funcionais, hooks para gerenciamento de estado e React Router para navegação entre páginas. A comunicação entre frontend e backend é feita através da API REST:

```text
React + TypeScript
        ↓
      HTTP
        ↓
  Spring Boot
        ↓
 Spring Data JPA
        ↓
   PostgreSQL
```

---

## Funcionalidades

### Alunos

- Cadastro, listagem, busca por ID, atualização e exclusão
- Indicação visual de status do aluno

### Exercícios

- Cadastro, listagem, atualização e exclusão
- Identificação do grupo muscular

### Treinos

- Cadastro, listagem, atualização e exclusão
- Associação de treino a um aluno

### Exercícios nos treinos

- Associação de exercícios a um treino
- Definição de séries e repetições
- Listagem, atualização e exclusão dos exercícios de um treino

### Interface

- Dashboard
- Sidebar, header e navegação entre páginas
- Componentes reutilizáveis
- Layout responsivo

---

## Endpoints



URL base: `http://localhost:8080`

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/alunos` | Lista todos os alunos |
| `GET` | `/alunos/{id}` | Busca um aluno por ID |
| `POST` | `/alunos` | Cadastra um novo aluno |
| `PUT` | `/alunos/{id}` | Atualiza um aluno |
| `DELETE` | `/alunos/{id}` | Remove um aluno |

O mesmo padrão se aplica aos recursos de exercícios e treinos.

---

## Conhecimentos praticados

**Backend:** arquitetura em camadas (Controller, Service e Repository), injeção de dependências, mapeamento de entidades com JPA e Hibernate, relacionamentos entre entidades, padrão DTO com `record`, construção de APIs REST e modelagem de banco de dados relacional.

**Frontend:** componentes funcionais em React com TypeScript, gerenciamento de estado com hooks, roteamento com React Router, formulários controlados e consumo de API REST com tratamento assíncrono.

---

## Como executar

### Pré-requisitos

Java 25, Maven, PostgreSQL, Node.js, npm e Git.

### 1. Banco de dados

Crie um banco PostgreSQL chamado `gymmanager`.

O projeto utiliza variáveis de ambiente para as credenciais:

```bash
DB_USERNAME=seu_usuario
DB_PASSWORD=sua_senha
```

O `application.properties` consome essas variáveis:

```properties
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
```

> As credenciais não devem ser colocadas diretamente no repositório.

### 2. Backend

Na raiz do projeto:

```bash
# Windows
mvnw.cmd spring-boot:run

# Linux / macOS
./mvnw spring-boot:run
```

A API estará disponível em `http://localhost:8080`.

### 3. Frontend

```bash
cd frontend
npm install
npm run dev
```

O frontend estará disponível em `http://localhost:5173`.

---

## Próximos passos

- Bean Validation e tratamento global de exceções com `@ControllerAdvice`
- Documentação da API com Swagger / OpenAPI
- Testes unitários e de integração
- Autenticação e controle de acesso
- Deploy do backend, do frontend e do banco de dados



As melhorias menores estão registradas nas [Issues](https://github.com/felipebagarelli/gymmanager/issues) do repositório.

---

## Sobre o projeto

O Gym Manager faz parte da minha jornada de estudos em desenvolvimento de software, com foco inicial em Backend Java e evolução gradual para Full Stack. Ele é construído de forma incremental, usando cada nova funcionalidade como oportunidade de aplicar na prática os conceitos estudados.

**Felipe Bagarelli** · [LinkedIn](https://www.linkedin.com/in/felipebagarelli) · fbagarelli@gmail.com
