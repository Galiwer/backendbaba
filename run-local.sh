#!/bin/bash

echo "🚀 Starting Health Records Backend for Local Development"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please run ./setup-local-dev.sh first"
    exit 1
fi

# Load environment variables
echo "📝 Loading environment variables from .env file..."
source .env

# Check if required environment variables are set
if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ]; then
    echo "❌ Missing required environment variables. Please check your .env file"
    echo "Required: MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD"
    exit 1
fi

echo "✅ Environment variables loaded"
echo "   MYSQL_HOST: $MYSQL_HOST"
echo "   MYSQL_USER: $MYSQL_USER"
echo "   MYSQL_DATABASE: $MYSQL_DATABASE"
echo "   NODE_ENV: $NODE_ENV"
echo ""

# Build and run the application
echo "🔨 Building and running the application..."
bal run
