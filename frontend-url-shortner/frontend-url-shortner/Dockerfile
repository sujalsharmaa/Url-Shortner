# Stage 1: Build the Next.js application
FROM node:18-alpine AS builder

# Set the working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy the entire application code
COPY . .

# Build the application for production
RUN npm run build

# Stage 2: Create a lightweight production image with Nginx
FROM nginx:stable-alpine

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Remove default Nginx index page
RUN rm -rf /usr/share/nginx/html/*

# Copy the Next.js build output from the builder stage to Nginx
COPY --from=builder /app/out /usr/share/nginx/html

# Expose port 80 for the container
EXPOSE 80

# Start Nginx when the container runs
CMD ["nginx", "-g", "daemon off;"]
 