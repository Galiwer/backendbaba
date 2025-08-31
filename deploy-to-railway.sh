#!/bin/bash

# Railway Deployment Script for Health Records Backend
echo "🚀 Preparing for Railway Deployment..."

# Check if we're in the right directory
if [ ! -f "main.bal" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI is not installed. Please install it first:"
    echo "   npm install -g @railway/cli"
    exit 1
fi

# Build the project
echo "📦 Building Ballerina project..."
bal build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "🎯 Ready for Railway Deployment!"
echo ""
echo "📋 Next Steps:"
echo "1. Make sure you have Railway CLI installed: npm install -g @railway/cli"
echo "2. Login to Railway: railway login"
echo "3. Link to your Railway project: railway link"
echo "4. Deploy to Railway: railway up"
echo ""
echo "🔧 Environment Variables (Railway will set these automatically for internal communication):"
echo "   MYSQL_HOST=mysql.railway.internal (automatically set by Railway)"
echo "   MYSQL_PORT=3306"
echo "   MYSQL_USER=root"
echo "   MYSQL_PASSWORD=your-railway-mysql-password"
echo "   MYSQL_DATABASE=railway"
echo ""
echo "💡 Note: Since both services are on Railway, they communicate internally!"
echo "   Railway automatically handles the internal networking and service discovery."
echo ""
echo "🔗 Test your deployment with:"
echo "curl -X POST https://your-app.railway.app/health/signup \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"firstName\":\"Test\",\"lastName\":\"User\",\"email\":\"test@example.com\",\"password\":\"password123\",\"gender\":\"male\",\"dateOfBirth\":\"1990-01-01\"}'"
echo ""
echo "✅ Ready to deploy to Railway!"
