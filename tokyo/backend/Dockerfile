FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --production

COPY . .

ENV NODE_ENV=production
EXPOSE 8080

CMD ["sh", "-c", "node src/index.js || node src\\index.js"]
