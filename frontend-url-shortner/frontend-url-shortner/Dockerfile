FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

ENV NEXT_TELEMETRY_DISABLED 1
ENV NEXT_PUBLIC_API_URL=http://backend.nodejs.com
ENV NEXT_PUBLIC_DOMAIN=https://sujalsharmaprojects.online

RUN npm run build

EXPOSE 3001

CMD ["npx", "next", "start", "-p", "3001"]