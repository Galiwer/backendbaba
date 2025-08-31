#!/bin/bash

# Railway Hostname Fix Script
echo "🔧 Fixing Railway Hostname Issue..."

echo ""
echo "🚨 Issue: MYSQLHOST = backendbaba.railway.internal (should be external)"
echo ""

echo "📋 Quick Fix - Use External Connection:"
echo ""

echo "1️⃣ Go to Railway Dashboard:"
echo "   - Visit https://railway.app/dashboard"
echo "   - Click on your backend service"
echo "   - Go to 'Variables' tab"
echo ""

echo "2️⃣ Set these environment variables:"
echo "   MYSQLHOST=tramway.proxy.rlwy.net"
echo "   MYSQLPORT=42634"
echo "   MYSQLUSER=root"
echo "   MYSQLPASSWORD=ElBlPtqKfjEFfDBjcYzwfuqcTVTzEHCl"
echo "   MYSQLDATABASE=railway"
echo ""

echo "3️⃣ Alternative - Use MYSQL_URL:"
echo "   MYSQL_URL=mysql://root:ElBlPtqKfjEFfDBjcYzwfuqcTVTzEHCl@tramway.proxy.rlwy.net:42634/railway"
echo ""

echo "4️⃣ Redeploy:"
echo "   railway up"
echo ""

echo "5️⃣ Check logs:"
echo "   railway logs"
echo ""

echo "🔍 Why this happens:"
echo "   - Railway internal hostnames can be inconsistent"
echo "   - External connections are more reliable"
echo "   - Service names affect internal DNS resolution"
echo ""

echo "✅ Expected result after fix:"
echo "   DEBUG: MYSQLHOST = tramway.proxy.rlwy.net"
echo "   Database connection successful"
echo ""

echo "🎯 Recommendation: Use external connection for reliability!"
