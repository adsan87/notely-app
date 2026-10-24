FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm run build

# Exercise 5: the page is served by its own small server (server.js), which is
# also the reverse proxy to the API: /api/* and /health go to API_URL.
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN npm install --omit=dev
COPY server.js ./
COPY --from=build /app/dist ./dist
# Cloud Run injects PORT (8080 unless you change the container port);
# API_URL, the API's address, is set on the service.
EXPOSE 8080
CMD ["node", "server.js"]
