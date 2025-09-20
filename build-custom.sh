#!/bin/bash

# Build script for custom Serenidad Chat (Mattermost fork)
# This script builds your custom Mattermost fork and deploys it

set -e

echo "🚀 Building Serenidad Chat (Custom Mattermost Fork)..."

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p volumes/app/mattermost/{config,data,logs,plugins,client/plugins,bleve-indexes}
mkdir -p volumes/web/cert
mkdir -p nginx

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R 2000:2000 volumes/app/mattermost/ 2>/dev/null || echo "Note: Run with sudo to set proper permissions"

# Build the custom image
echo "🔨 Building custom Mattermost image..."
docker-compose build mattermost

# Start the services
echo "🚀 Starting services..."
docker-compose up -d

echo "✅ Serenidad Chat is now running!"
echo "🌐 Access your custom Mattermost at: http://localhost:8065"
echo "📊 Check logs with: docker-compose logs -f mattermost"
echo "🛑 Stop with: docker-compose down"
