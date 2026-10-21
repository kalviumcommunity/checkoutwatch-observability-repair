FROM node:22.14.0-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server.js ./
USER node
EXPOSE 8080
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 CMD node -e "require('node:http').get('http://localhost:8080/healthz',r=>{console.log('probe HTTP '+r.statusCode);r.resume();process.exit(r.statusCode===200?0:1)}).on('error',e=>{console.error(e.message);process.exit(1)})"
CMD ["node", "server.js"]
