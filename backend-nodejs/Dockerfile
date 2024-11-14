# First stage: Build dependencies
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Second stage: Production
FROM node:18-alpine
WORKDIR /app
COPY --from=build /app .

# Set environment variables
ENV DB_HOST=postgres.cxges422mlzz.us-east-1.rds.amazonaws.com \
    DB_NAME=postgres \
    DB_USER=postgres \
    DB_PASS=postgres \
    REDIS_HOST=54.166.200.41 \
    REDIS_PORT=6379 \
    JWT_SECRET=secret \
    URL_SHORTNER_LINK=http://localhost:5000

EXPOSE 3000
CMD ["node", "server.js"]
