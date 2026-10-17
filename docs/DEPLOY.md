# Deploy em produção (VPS + Docker Compose)

Arquitetura: uma VPS com 3 containers — **db** (PostgreSQL), **backend** (Spring Boot) e **web** (Caddy: serve o painel e faz HTTPS automático).
Só o Caddy expõe portas (80/443). Painel em `APP_DOMAIN`, API em `API_DOMAIN` (hosts separados).

## 1. Pré-requisitos
- VPS Linux (2 GB de RAM é suficiente para começar) com Docker + Docker Compose.
- Dois registros DNS `A` apontando para o IP da VPS: `app.seudominio.com` e `api.seudominio.com`.
- Portas 80 e 443 liberadas no firewall (o resto fechado).

## 2. Primeiro deploy
```bash
git clone <repo> /opt/gymmanager && cd /opt/gymmanager
cp .env.example .env.prod          # preencha (JWT_SECRET: openssl rand -base64 48)
chmod 600 .env.prod
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
docker compose -f docker-compose.prod.yml --env-file .env.prod logs -f backend
```
O Flyway cria o schema (V1..V4) sozinho em banco novo. Confirme: `https://api.seudominio.com/actuator/health` → `{"status":"UP"}`.

O painel é montado com a URL da API **no build** (`VITE_API_URL`). Se mudar o domínio da API, rebuild do serviço `web`.

## 3. Primeiro personal
Não há usuário inicial. Cadastre pelo endpoint público:
`POST https://api.seudominio.com/api/v1/auth/register-trainer` (`email`, `password` ≥ 8, `displayName`).
Depois entre no painel; os alunos são criados pelo personal.

## 4. Integrações (opcionais, ligam ao definir as variáveis)
- **IA**: `AI_API_KEY` (Anthropic). Sem chave, o assistente responde "indisponível". Limite por aluno: `AI_DAILY_LIMIT`.
- **Pagamentos (Stripe Connect)**: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `PLATFORM_FEE_PERCENT`.
- **E-mail (cadastro, troca de senha, responsável)**: `MAIL_HOST`, `MAIL_PORT` (587), `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` (ex.: `GymManager <nao-responda@seudominio.com.br>`). Brevo, Resend e Amazon SES funcionam por SMTP. Sem `MAIL_HOST`, os e-mails só aparecem no log (desenvolvimento).
- **Endereço público e documentos**: `PUBLIC_URL` (endereço HTTPS do backend, usado no link do responsável), `TERMS_VERSION`, `TERMS_URL`, `PRIVACY_URL`. Mudar `TERMS_VERSION` obriga novos cadastros a aceitar a versão nova.
  No painel da Stripe crie o webhook `https://api.seudominio.com/api/v1/billing/webhook` para **eventos de contas conectadas** com:
  `checkout.session.completed`, `invoice.paid`, `invoice.payment_failed`, `customer.subscription.deleted`, `account.updated`.
  Teste antes com o Stripe CLI e chaves de teste (`sk_test_…`); só então use as chaves reais.

## 5. Atualizar versão
```bash
git pull && docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```
Migrations rodam no start. **Faça backup antes** de qualquer versão com migration nova.

## 6. Backup e restauração
```bash
sudo cp deploy/backup.sh /usr/local/bin/gymmanager-backup && sudo chmod +x /usr/local/bin/gymmanager-backup
# cron (03:00): 0 3 * * * /opt/gymmanager/deploy/backup.sh
```
Restaurar:
```bash
gunzip -c gymmanager-AAAAMMDD-HHMMSS.sql.gz | docker compose -f docker-compose.prod.yml --env-file .env.prod exec -T db sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
```
Copie os backups para **fora** da VPS (bucket/outro servidor) e teste uma restauração pelo menos uma vez.

## 7. App do aluno (Flutter)
O app mobile não roda na VPS: gere os pacotes com a URL da API e publique nas lojas.
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.seudominio.com
flutter build ipa --release --dart-define=API_BASE_URL=https://api.seudominio.com   # requer macOS
```
Pendente para as lojas (não feito): ícone/nome finais, assinatura de release (keystore), política de privacidade e termos.

## 8. Checklist antes de abrir para clientes
- [ ] `JWT_SECRET` forte e exclusivo; `.env.prod` fora do git e com permissão 600.
- [ ] Senha do banco forte; porta 5432 **não** publicada (o compose já não publica).
- [ ] Backup diário funcionando **e** cópia externa **e** restauração testada.
- [ ] HTTPS válido nos dois domínios; `CORS_ALLOWED_ORIGINS` = só o domínio do painel (o compose já faz).
- [ ] Stripe: modo teste validado ponta a ponta (onboarding do personal, assinatura, atraso → bloqueio, cancelamento).
- [ ] Monitoramento externo em `/actuator/health` (ex.: UptimeRobot) com alerta por e-mail.
- [ ] Termos de uso e política de privacidade (LGPD: dados de saúde/treino e de pagamento).

## 9. Limites conhecidos
- **Uma instância do backend.** O limitador de tentativas de login e o limite diário da IA (este é gravado no banco) funcionam assim; o limitador de login é em memória e reseta ao reiniciar. Para escalar horizontalmente, mover o limitador para armazenamento compartilhado.
- **Fuso horário único.** A API grava horários sem fuso (`LocalDateTime`) e o app os lê como hora local; por isso o container do backend roda com `TZ=America/Sao_Paulo` (variável `APP_TIMEZONE` no `.env.prod`). Alunos em outro fuso veriam dias e cronômetro deslocados. Trocar o fuso depois de haver treinos gravados desloca os horários antigos.
- Sem envio de e-mail (recuperação de senha, avisos de cobrança) e sem push notifications.
- Imagens Docker e este roteiro **não foram executados** no ambiente de desenvolvimento (sem Docker instalado); o jar, o perfil `prod` e o build do painel foram verificados localmente.
