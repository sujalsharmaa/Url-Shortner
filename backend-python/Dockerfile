# Stage 1: Build the dependencies
FROM python:3.9-slim AS builder

WORKDIR /app

COPY requirement.txt .
RUN pip install --no-cache-dir -r requirement.txt

# Stage 2: Copy the application code and set up the runtime environment
FROM python:3.9-slim

WORKDIR /app
ENV DB_HOST=postgres.backend.postgres.com  \
    DB_NAME=postgres \
    DB_USER=postgres \
    DB_PASS=postgres \
    REDIS_HOST=backend.redis.com \         
    REDIS_PORT=6379 \
    APP_PORT=5000 \
    PROMETHEUS_PORT=9090

COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY . .

EXPOSE 5000

# Run the application
CMD ["python", "app.py"]
