# Stage 1: Builder
FROM node:20 AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build


# Stage 2: Production runtime
FROM node:20-alpine AS runtime

WORKDIR /app

ENV APP_ENV=production
ENV NODE_ENV=production

COPY --from=builder /app/server.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/dist/build-manifest.json ./dist/build-manifest.json

USER node

EXPOSE 4173

CMD ["node", "server.js"]
