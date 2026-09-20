# Painel do personal (React) servido pelo Caddy, que tambem faz o HTTPS automatico.
# Build a partir da raiz do repositorio: docker compose -f docker-compose.prod.yml build
FROM node:22-alpine AS web
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend ./
# URL publica da API (ex.: https://api.seudominio.com), embutida no build
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

FROM caddy:2-alpine
COPY --from=web /app/dist /srv
COPY deploy/Caddyfile /etc/caddy/Caddyfile
