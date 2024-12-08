# First stage: Build dependencies
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Second stage: Production
FROM node:18-alpine
WORKDIR /app
ENV DB_HOST=postgres.backend.postgres.com  \
    DB_NAME=postgres \
    DB_USER=postgres \
    DB_PASS=postgres \
    REDIS_HOST=backend.redis.com \       
    REDIS_PORT=6379 \
    JWT_SECRET=secret \
    URL_SHORTNER_LINK=http://backend.python.com \
    FRONTEND_URL=https://www.sujalsharmaprojects.online \
    ENV=prod
COPY --from=build /app . 
EXPOSE 3000
CMD ["node", "server.js"]
 