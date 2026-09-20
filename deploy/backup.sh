#!/usr/bin/env bash
# Backup diario do PostgreSQL (rodar no host da VPS via cron). Mantem os ultimos 14 dias.
# Exemplo de cron:  0 3 * * * /opt/gymmanager/deploy/backup.sh >> /var/log/gymmanager-backup.log 2>&1
# IMPORTANTE: copie os arquivos tambem para fora da VPS (bucket/outro servidor) - backup no mesmo disco nao protege de perda do disco.
set -euo pipefail

DIR="${BACKUP_DIR:-/var/backups/gymmanager}"
COMPOSE="docker compose -f $(dirname "$0")/../docker-compose.prod.yml --env-file $(dirname "$0")/../.env.prod"
mkdir -p "$DIR"

FILE="$DIR/gymmanager-$(date +%Y%m%d-%H%M%S).sql.gz"
$COMPOSE exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$FILE"
test -s "$FILE"
find "$DIR" -name 'gymmanager-*.sql.gz' -mtime +14 -delete
echo "backup ok: $FILE"
