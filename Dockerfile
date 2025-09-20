# Build custom web client
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

# Use official Mattermost server as base
FROM mattermost/mattermost-team-edition:latest

# Switch to root to make modifications
USER root

# Backup original client and replace with custom build
RUN mv /mattermost/client /mattermost/client-original
COPY --from=webapp-build /mattermost/webapp/dist /mattermost/client

# Set ownership of the new client directory
RUN chown -R mattermost:mattermost /mattermost/client

# Switch back to mattermost user
USER mattermost

# The rest is handled by the base image (ports, healthcheck, CMD)
