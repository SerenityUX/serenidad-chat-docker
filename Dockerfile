# Multi-stage build for custom Mattermost fork
# Force rebuild by using a unique timestamp
FROM node:18-alpine AS webapp-build

# Force rebuild by adding a unique layer
RUN echo "BUILD_TIMESTAMP=$(date +%s)" > /tmp/build_info.txt && \
    echo "=== FORCING FRESH BUILD ===" && \
    echo "Timestamp: $(date)" && \
    echo "Random: $(shuf -i 1-1000000 -n 1)" && \
    echo "=== BUILD STARTING ===" && \
    echo "This is a fresh build at $(date +%s)" > /tmp/fresh_build.txt

# Install build dependencies
RUN apk add --no-cache git make g++ python3

# Set working directory
WORKDIR /mattermost

# Clone your custom fork with aggressive cache busting
RUN echo "=== FORCING FRESH BUILD ===" && \
    echo "Timestamp: $(date)" && \
    echo "Random: $(shuf -i 1-1000000 -n 1)" && \
    rm -rf /mattermost/* /mattermost/.* 2>/dev/null || true && \
    git clone https://github.com/SerenityUX/serenidad-chat.git . && \
    echo "=== REPOSITORY VERIFICATION ===" && \
    git remote -v && \
    git log --oneline -5 && \
    echo "=== BUILD STARTING ==="

# Install webapp dependencies and build
WORKDIR /mattermost/webapp
RUN npm install --no-audit --no-fund
RUN npm run build

# Build the server
# Force rebuild by using a unique timestamp
FROM golang:1.21-alpine AS server-build

# Force rebuild by adding a unique layer
RUN echo "BUILD_TIMESTAMP=$(date +%s)" > /tmp/build_info.txt && \
    echo "=== FORCING FRESH BUILD ===" && \
    echo "Timestamp: $(date)" && \
    echo "Random: $(shuf -i 1-1000000 -n 1)" && \
    echo "=== BUILD STARTING ===" && \
    echo "This is a fresh build at $(date +%s)" > /tmp/fresh_build.txt

# Install build dependencies
RUN apk add --no-cache git make g++

# Set working directory
WORKDIR /mattermost

# Clone your custom fork with aggressive cache busting
RUN echo "=== FORCING FRESH BUILD ===" && \
    echo "Timestamp: $(date)" && \
    echo "Random: $(shuf -i 1-1000000 -n 1)" && \
    rm -rf /mattermost/* /mattermost/.* 2>/dev/null || true && \
    git clone https://github.com/SerenityUX/serenidad-chat.git . && \
    echo "=== REPOSITORY VERIFICATION ===" && \
    git remote -v && \
    git log --oneline -5 && \
    echo "=== BUILD STARTING ==="

# Build the server - navigate to server directory and build
RUN echo "=== CHECKING REPOSITORY STRUCTURE ===" && \
    ls -la && \
    echo "=== NAVIGATING TO SERVER DIRECTORY ===" && \
    cd server && \
    ls -la && \
    echo "=== GO MODULE ALREADY EXISTS, DOWNLOADING DEPENDENCIES ===" && \
    go mod tidy && \
    echo "=== BUILDING SERVER FROM ./cmd/mattermost ===" && \
    go build -o ../bin/mattermost ./cmd/mattermost && \
    echo "=== BUILD SUCCESSFUL ===" && \
    ls -la ../bin/

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

# Force final rebuild with unique timestamp
RUN echo "FINAL_BUILD_TIMESTAMP=$(date +%s)" > /tmp/final_build_info.txt && \
    echo "This build completed at: $(date)" && \
    echo "Build hash: $(echo $FINAL_BUILD_TIMESTAMP | sha256sum | cut -d' ' -f1)" && \
    echo "=== FINAL BUILD COMPLETE ===" && \
    echo "Random: $(shuf -i 1-1000000 -n 1)" && \
    echo "=== BUILD FINISHED ===" && \
    echo "This is a fresh build at $(date +%s)" > /tmp/final_fresh_build.txt

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
