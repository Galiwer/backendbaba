#!/bin/bash

echo "🚀 Setting up Local Development Environment for Health Records Backend"
echo ""

# Check if MySQL is installed
if ! command -v mysql &> /dev/null; then
    echo "❌ MySQL is not installed. Please install MySQL first:"
    echo ""
    echo "For macOS (using Homebrew):"
    echo "  brew install mysql"
    echo "  brew services start mysql"
    echo ""
    echo "For Ubuntu/Debian:"
    echo "  sudo apt-get install mysql-server"
    echo "  sudo systemctl start mysql"
    echo ""
    echo "For Windows:"
    echo "  Download and install MySQL from https://dev.mysql.com/downloads/mysql/"
    echo ""
    exit 1
fi

echo "✅ MySQL is installed"

# Check if MySQL is running
if ! mysqladmin ping -h localhost -u root --silent; then
    echo "❌ MySQL is not running. Please start MySQL:"
    echo ""
    echo "For macOS:"
    echo "  brew services start mysql"
    echo ""
    echo "For Ubuntu/Debian:"
    echo "  sudo systemctl start mysql"
    echo ""
    echo "For Windows:"
    echo "  Start MySQL service from Services or MySQL Workbench"
    echo ""
    exit 1
fi

echo "✅ MySQL is running"

# Set up environment variables
echo ""
echo "📝 Setting up environment variables..."

# Create .env file for local development
cat > .env << EOF
# Local Development MySQL Configuration
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=password
MYSQL_DATABASE=babadb

# Application config
PORT=9090
NODE_ENV=development
EOF

echo "✅ Created .env file with local development settings"
echo ""

echo "🔧 Next steps:"
echo "1. Set your MySQL root password (if not already set):"
echo "   mysql -u root -p"
echo "   ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_password';"
echo ""
echo "2. Update the .env file with your actual MySQL password"
echo ""
echo "3. Run the application:"
echo "   source .env && bal run"
echo ""
echo "4. Or run with environment variables directly:"
echo "   MYSQL_HOST=localhost MYSQL_USER=root MYSQL_PASSWORD=your_password MYSQL_DATABASE=babadb NODE_ENV=development bal run"
echo ""
echo "🎯 The application will automatically:"
echo "   - Create the 'babadb' database if it doesn't exist"
echo "   - Create all required tables"
echo "   - Start the API server on port 9090"
echo ""
echo "✅ Setup complete!"
