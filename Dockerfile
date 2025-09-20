# Multi-stage build for custom Mattermost fork
# Cache busting - never cache this layer
ARG CACHE_BUST
FROM node:18-alpine AS webapp-build

# Install build dependencies
RUN apk add --no-cache git make g++ python3

# Set working directory
WORKDIR /mattermost

# Clone your custom fork with cache busting
RUN echo "Cache bust: $(date +%s)" && \
    git clone https://github.com/SerenityUX/serenidad-chat.git . && \
    echo "Repository cloned successfully" && \
    git remote -v && \
    git log --oneline -5

# Install webapp dependencies and build
WORKDIR /mattermost/webapp
RUN npm ci --no-audit --no-fund
RUN npm run build

# Build the server
# Cache busting - never cache this layer
ARG CACHE_BUST
FROM golang:1.21-alpine AS server-build

# Install build dependencies
RUN apk add --no-cache git make g++

# Set working directory
WORKDIR /mattermost

# Clone your custom fork with cache busting
RUN echo "Cache bust: $(date +%s)" && \
    git clone https://github.com/SerenityUX/serenidad-chat.git . && \
    echo "Repository cloned successfully" && \
    git remote -v && \
    git log --oneline -5

# Build the server
RUN make build-linux

# Final runtime image
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Create mattermost user
RUN addgroup -g 2000 mattermost && \
    adduser -D -u 2000 -G mattermost mattermost

# Set working directory
WORKDIR /mattermost

# Copy built binaries and assets
COPY --from=server-build /mattermost/bin/mattermost /mattermost/bin/mattermost
COPY --from=webapp-build /mattermost/webapp/dist /mattermost/client

# Debug: Show what we're actually running
RUN echo "=== SERVER BUILD INFO ===" && \
    /mattermost/bin/mattermost version && \
    echo "=== CLIENT BUILD INFO ===" && \
    ls -la /mattermost/client/ && \
    echo "=== BUILD COMPLETE ==="

# Create necessary directories
RUN mkdir -p /mattermost/config /mattermost/data /mattermost/logs /mattermost/plugins /mattermost/client/plugins /mattermost/bleve-indexes

# Set ownership
RUN chown -R mattermost:mattermost /mattermost

# Switch to mattermost user
USER mattermost

# Expose port
EXPOSE 8065

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8065/api/v4/system/ping || exit 1

# Start Mattermost
CMD ["/mattermost/bin/mattermost"]
