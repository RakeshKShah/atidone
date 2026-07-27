FROM node:22-bookworm-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        bash \
        netcat-openbsd \
        jq \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm@10.30.1

# Copy manifests first for better layer caching
COPY package.json pnpm-lock.yaml ./

# Install dependencies with lifecycle scripts disabled (postinstall: nuxt prepare needs source)
RUN pnpm install --frozen-lockfile --ignore-scripts

# Copy application source
COPY . .

# Run postinstall codegen (nuxt prepare) now that source is present
RUN pnpm run postinstall

# Build the application
RUN pnpm run build

ENV PORT=6713
EXPOSE 6713

COPY .codevalid/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", ".output/server/index.mjs"]
