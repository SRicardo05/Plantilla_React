# syntax=docker/dockerfile:1.6
# Etapas optimizadas para build React

# 1. Dependencias (usa caché de npm con BuildKit)
FROM node:20-alpine AS deps
WORKDIR /app
ENV CI=true
COPY package*.json ./
# Con BuildKit se monta caché para acelerar instalaciones sucesivas
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

# 2. Build aplicación
FROM node:20-alpine AS build
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# 3. Imagen final ligera con nginx
FROM nginx:1.25-alpine AS runtime
LABEL maintainer="hosting-platform" \
    project.type="react-static" \
    platform.layer="runtime" \
    build.node.version="20" \
    build.optimized="true"

# Copiar artefactos estáticos
COPY --from=build /app/dist /usr/share/nginx/html

# Healthcheck para monitoreo automático
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
