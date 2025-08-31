#!/bin/bash

# Choreo Deployment Script for Health Records Backend
echo "🚀 Preparing for Choreo Deployment..."

# Check if we're in the right directory
if [ ! -f "main.bal" ]; then
    echo "❌ Error: Please run this script from the backend/ballerinahealthrec directory"
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
echo "🎯 Ready for Choreo Deployment!"
echo ""
echo "📋 Next Steps:"
echo "1. Go to https://console.choreo.dev/"
echo "2. Create a new project"
echo "3. Import this directory (backend/ballerinahealthrec)"
echo "4. Set these environment variables:"
echo ""
echo "   MYSQL_HOST=mysql.railway.internal"
echo "   MYSQL_PORT=3306"
echo "   MYSQL_USER=root"
echo "   MYSQL_PASSWORD=ElBlPtqKfjEFfDBjcYzwfuqcTVTzEHCl"
echo "   MYSQL_DATABASE=railway"
echo ""
echo "5. Deploy to Choreo"
echo "6. Get your service URL (e.g., https://your-app.choreo.dev)"
echo ""
echo "🔗 Test your deployment with:"
echo "curl -X POST https://your-app.choreo.dev/health/signup \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"firstName\":\"Test\",\"lastName\":\"User\",\"email\":\"test@example.com\",\"password\":\"password123\",\"gender\":\"male\",\"dateOfBirth\":\"1990-01-01\"}'"
echo ""
echo "✅ Your Railway MySQL database is ready and waiting!"
