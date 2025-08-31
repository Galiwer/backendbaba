#!/bin/bash

echo "🚀 Starting Health Records Backend with Railway MySQL Database"
echo ""

# Set Railway MySQL environment variables
export MYSQL_URI=jdbc:mysql://tramway.proxy.rlwy.net:42634/railway?user=root&password=ElBlPtqKfjEFfDBjcYzwfuqcTVTzEHCl&useSSL=false&allowPublicKeyRetrieval=true&autoCommit=true&serverTimezone=UTC&useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&connectTimeout=30000&socketTimeout=30000&maxReconnects=3&failOverReadOnly=false&initialTimeout=10&maxPoolSize=5&minPoolSize=1
export MYSQL_HOST=tramway.proxy.rlwy.net
export MYSQL_PORT=42634
export MYSQL_USER=root
export MYSQL_PASSWORD=ElBlPtqKfjEFfDBjcYzwfuqcTVTzEHCl
export MYSQL_DATABASE=railway
export NODE_ENV=development
export PORT=9090

echo "✅ Environment variables set for Railway MySQL"
echo "   MYSQL_HOST: $MYSQL_HOST"
echo "   MYSQL_PORT: $MYSQL_PORT"
echo "   MYSQL_USER: $MYSQL_USER"
echo "   MYSQL_DATABASE: $MYSQL_DATABASE"
echo "   NODE_ENV: $NODE_ENV"
echo ""

# Test database connection first
echo "🔍 Testing database connection..."
if command -v mysql &> /dev/null; then
    if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" "$MYSQL_DATABASE" 2>/dev/null; then
        echo "✅ Database connection successful!"
    else
        echo "❌ Database connection failed. Please check your Railway MySQL credentials."
        exit 1
    fi
else
    echo "⚠️  MySQL client not found, skipping connection test"
fi

echo ""

# Build and run the application
echo "🔨 Building and running the application..."
bal run
    