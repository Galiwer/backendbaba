#!/bin/bash

echo "🚀 Starting Health Records Backend with Local MySQL Database"
echo ""

# Check if MySQL is running locally
if ! mysqladmin ping -h localhost -u root --silent 2>/dev/null; then
    echo "❌ Local MySQL is not running. Please start MySQL first:"
    echo ""
    echo "For macOS:"
    echo "  brew services start mysql"
    echo ""
    echo "For Ubuntu/Debian:"
    echo "  sudo systemctl start mysql"
    echo ""
    echo "For Windows:"
    echo "  Start MySQL service from Services"
    echo ""
    exit 1
fi

echo "✅ Local MySQL is running"

# Set local MySQL environment variables
export MYSQL_HOST=localhost
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASSWORD=password
export MYSQL_DATABASE=babadb
export NODE_ENV=development
export PORT=9090

echo "✅ Environment variables set for Local MySQL"
echo "   MYSQL_HOST: $MYSQL_HOST"
echo "   MYSQL_PORT: $MYSQL_PORT"
echo "   MYSQL_USER: $MYSQL_USER"
echo "   MYSQL_DATABASE: $MYSQL_DATABASE"
echo "   NODE_ENV: $NODE_ENV"
echo ""

# Test database connection
echo "🔍 Testing database connection..."
if mysql -h localhost -u root -ppassword -e "SELECT 1;" 2>/dev/null; then
    echo "✅ Database connection successful!"
else
    echo "❌ Database connection failed. Please check your MySQL password."
    echo "You may need to set the password:"
    echo "  mysql -u root -p"
    echo "  ALTER USER 'root'@'localhost' IDENTIFIED BY 'password';"
    exit 1
fi

echo ""

# Build and run the application
echo "🔨 Building and running the application..."
bal run
