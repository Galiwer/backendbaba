#!/bin/bash

# Test Railway Deployment Script
echo "🧪 Testing Railway Deployment..."

# Check if URL is provided
if [ -z "$1" ]; then
    echo "❌ Error: Please provide your Railway app URL"
    echo "Usage: ./test-railway-deployment.sh https://your-app.railway.app"
    exit 1
fi

APP_URL=$1

echo "🔗 Testing app at: $APP_URL"
echo ""

# Test health endpoint
echo "📊 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$APP_URL/health")
HEALTH_HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | head -n -1)

if [ "$HEALTH_HTTP_CODE" = "200" ]; then
    echo "✅ Health check passed!"
    echo "Response: $HEALTH_BODY"
else
    echo "❌ Health check failed with status: $HEALTH_HTTP_CODE"
    echo "Response: $HEALTH_BODY"
fi

echo ""

# Test signup endpoint
echo "📝 Testing signup endpoint..."
SIGNUP_PAYLOAD='{
  "firstName": "Test",
  "lastName": "User",
  "email": "test-railway-'$(date +%s)'@example.com",
  "password": "password123",
  "gender": "male",
  "dateOfBirth": "1990-01-01"
}'

SIGNUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APP_URL/health/signup" \
  -H "Content-Type: application/json" \
  -d "$SIGNUP_PAYLOAD")

SIGNUP_HTTP_CODE=$(echo "$SIGNUP_RESPONSE" | tail -n1)
SIGNUP_BODY=$(echo "$SIGNUP_RESPONSE" | head -n -1)

if [ "$SIGNUP_HTTP_CODE" = "200" ] || [ "$SIGNUP_HTTP_CODE" = "201" ]; then
    echo "✅ Signup test passed!"
    echo "Response: $SIGNUP_BODY"
elif [ "$SIGNUP_HTTP_CODE" = "409" ]; then
    echo "⚠️  Signup test: User already exists (expected for duplicate email)"
    echo "Response: $SIGNUP_BODY"
else
    echo "❌ Signup test failed with status: $SIGNUP_HTTP_CODE"
    echo "Response: $SIGNUP_BODY"
fi

echo ""
echo "🎯 Railway deployment test completed!"
echo "🔗 Your app URL: $APP_URL"
