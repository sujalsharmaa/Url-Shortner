# Stage 1: Build the dependencies
FROM python:3.9-slim AS builder

WORKDIR /app

COPY requirement.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Copy the application code and set up the runtime environment
FROM python:3.9-slim

WORKDIR /app
COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY . .

EXPOSE 5000

# Run the application
CMD ["python", "app.py"]
