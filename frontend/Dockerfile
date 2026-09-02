FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
RUN npm install -g serve
COPY --from=build /app/dist ./dist
COPY --from=build /app/public ./public
EXPOSE 5173
ENV PORT=5173
CMD ["sh", "-c", "cp public/config.json dist/config.json && serve -s dist -l 5173"]
