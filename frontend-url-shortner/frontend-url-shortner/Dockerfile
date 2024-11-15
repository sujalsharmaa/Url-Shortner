# Stage 1: Build the Next.js app
FROM node:18 AS build

# Set working directory
WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy all the files and build the app
COPY . .

# Build the app
RUN npm run build

# Stage 2: Serve the app with Node.js
FROM node:18

# Set working directory
WORKDIR /app

# Copy the build output from the previous stage
COPY --from=build /app/ ./

# Install production dependencies (if not already installed)
RUN npm install --production

# Expose the default Next.js port
EXPOSE 3001

# Start the Next.js app in production mode
CMD ["npm", "start"]
