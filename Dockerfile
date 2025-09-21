# Build custom web client
FROM node:18-alpine AS webapp-build

# Install build dependencies for native packages
RUN apk add --no-cache \
    git make g++ python3 \
    autoconf automake libtool \
    pkgconfig pkg-config \
    nasm \
    libpng-dev \
    libjpeg-turbo-dev \
    giflib-dev \
    tiff-dev

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

# Simply replace the client directory with our custom build
# The COPY instruction will overwrite the existing /mattermost/client directory
COPY --from=webapp-build /mattermost/webapp/dist /mattermost/client

# The rest is handled by the base image (ports, healthcheck, CMD, user)
