# Builder stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .

# Build the Next.js application
RUN npm run build

# Export the static build if needed (only if `next export` is used)
# RUN npm run export

# Production stage
FROM nginx:stable-alpine AS production
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the Next.js build output to the Nginx HTML directory
# Use `.next` if not exporting or `out` if exporting
COPY --from=builder /app/.next /usr/share/nginx/html

# If you used `next export`, use:
# COPY --from=builder /app/out /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
