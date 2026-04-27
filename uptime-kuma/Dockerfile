# Generated Dockerfile for custom uptime-kuma build
FROM node:20-alpine AS build
WORKDIR /app
COPY . .
RUN npm ci --omit=dev && npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=build /app .
EXPOSE 3001
VOLUME ["/app/data"]
CMD ["node", "server/server.js", "--port=3001", "--data-dir=/app/data"]
