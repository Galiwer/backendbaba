#!/bin/bash

# Railway Connection Fix Script
echo "🔧 Fixing Railway Connection Issues..."

echo ""
echo "🚨 Current Issue: Connection refused to mysql.railway.internal"
echo ""

echo "📋 Step-by-Step Fix:"
echo ""

echo "1️⃣ Check Railway Dashboard:"
echo "   - Go to https://railway.app/dashboard"
echo "   - Verify MySQL service is running (green status)"
echo "   - Check if both services are in the same project"
echo ""

echo "2️⃣ Check Environment Variables:"
echo "   - Go to your backend service"
echo "   - Click 'Variables' tab"
echo "   - Verify these are set:"
echo "     MYSQL_HOST=mysql.railway.internal"
echo "     MYSQL_PORT=3306"
echo "     MYSQL_USER=root"
echo "     MYSQL_PASSWORD=<password>"
echo "     MYSQL_DATABASE=railway"
echo ""

echo "3️⃣ If variables are missing, add them manually:"
echo "   - Click 'New Variable'"
echo "   - Add each variable above"
echo ""

echo "4️⃣ Alternative: Use External Connection"
echo "   - Go to MySQL service"
echo "   - Click 'Connect' tab"
echo "   - Copy external connection details"
echo "   - Set MYSQL_HOST to external hostname"
echo ""

echo "5️⃣ Redeploy:"
echo "   railway up"
echo ""

echo "6️⃣ Check logs:"
echo "   railway logs"
echo ""

echo "🔍 Quick Commands:"
echo "   railway status          # Check service status"
echo "   railway logs            # View logs"
echo "   railway up              # Redeploy"
echo "   railway open            # Open in browser"
echo ""

echo "💡 If internal communication fails, use external connection:"
echo "   - Get external MySQL hostname from Railway dashboard"
echo "   - Set MYSQL_HOST to external hostname"
echo "   - Redeploy with: railway up"
echo ""

echo "✅ After fixing, test with:"
echo "   ./test-railway-deployment.sh https://your-app.railway.app"
