# SEBAR API image. Secrets come from env at runtime (never baked in); the DB CA cert is mounted.
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src
COPY db ./db
COPY drizzle ./drizzle

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT:-3000}/health || exit 1

# node directly (not npm start) so SIGTERM reaches the graceful shutdown in src/index.js.
CMD ["node", "src/index.js"]
