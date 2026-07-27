FROM node:22-bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget bash netcat-openbsd jq \
    && rm -rf /var/lib/apt/lists/*
RUN npm install -g pnpm@10.30.1
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY . .
RUN pnpm run postinstall
RUN pnpm run build
ENV PORT=6713
EXPOSE 6713
COPY .codevalid/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", ".output/server/index.mjs"]
