#!/bin/bash

# Test script for Choreo deployment
echo "🧪 Testing Choreo Deployment..."

# Check if URL is provided
if [ -z "$1" ]; then
    echo "❌ Usage: ./test-choreo-deployment.sh <your-choreo-url>"
    echo "Example: ./test-choreo-deployment.sh https://your-app.choreo.dev"
    exit 1
fi

CHOREO_URL=$1

echo "🔗 Testing URL: $CHOREO_URL"

# Test health endpoint
echo ""
echo "1️⃣ Testing Health Endpoint..."
curl -s "$CHOREO_URL/health" | jq .

# Test debug endpoint
echo ""
echo "2️⃣ Testing Debug Endpoint..."
curl -s "$CHOREO_URL/health/debug" | jq .

# Test signup endpoint
echo ""
echo "3️⃣ Testing Signup Endpoint..."
curl -X POST "$CHOREO_URL/health/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "password": "password123",
    "gender": "male",
    "dateOfBirth": "1990-01-01",
    "phoneNumber": "1234567890"
  }' | jq .

echo ""
echo "✅ Testing complete!"
echo ""
echo "📊 Check the debug endpoint again to see if the user was saved:"
echo "curl -s \"$CHOREO_URL/health/debug\" | jq ."
