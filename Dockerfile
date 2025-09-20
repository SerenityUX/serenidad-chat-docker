# Multi-stage build for custom Mattermost fork
FROM node:18-alpine AS webapp-build

# Install build dependencies
RUN apk add --no-cache git make g++ python3

# Set working directory
WORKDIR /mattermost

# Clone your custom fork
RUN git clone https://github.com/SerenityUX/serenidad-chat.git .

# Install webapp dependencies and build
WORKDIR /mattermost/webapp
RUN npm install --no-audit --no-fund
RUN npm run build

# Build the server
FROM golang:1.24-alpine AS server-build

# Install build dependencies
RUN apk add --no-cache git make g++

# Set working directory
WORKDIR /mattermost

# Clone your custom fork
RUN git clone https://github.com/SerenityUX/serenidad-chat.git .

# Build the server - navigate to server directory and build
RUN cd server && \
    go build -tags "!enterprise,!focalboard" -o ../bin/mattermost ./cmd/mattermost

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