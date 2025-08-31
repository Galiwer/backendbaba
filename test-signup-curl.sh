#!/bin/bash

# Test signup with JSON payloads
echo "🧪 Testing Signup with JSON Payloads"

# Check if URL is provided
if [ -z "$1" ]; then
    echo "❌ Usage: ./test-signup-curl.sh <your-choreo-url>"
    echo "Example: ./test-signup-curl.sh https://your-app.choreo.dev"
    exit 1
fi

CHOREO_URL=$1

echo "🔗 Testing URL: $CHOREO_URL"

# Test simple signup (without vaccines)
echo ""
echo "1️⃣ Testing Simple Signup (without vaccines)..."
curl -X POST "$CHOREO_URL/health/signup" \
  -H "Content-Type: application/json" \
  -d @test-signup-simple.json | jq .

# Test signup with vaccines
echo ""
echo "2️⃣ Testing Signup with Vaccines..."
curl -X POST "$CHOREO_URL/health/signup" \
  -H "Content-Type: application/json" \
  -d @test-signup-payload.json | jq .

# Test debug endpoint to see saved data
echo ""
echo "3️⃣ Checking Debug Data..."
curl -s "$CHOREO_URL/health/debug" | jq .

echo ""
echo "✅ Signup testing complete!"
echo ""
echo "📊 To test manually with curl:"
echo ""
echo "# Simple signup:"
echo "curl -X POST \"$CHOREO_URL/health/signup\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d @test-signup-simple.json"
echo ""
echo "# Signup with vaccines:"
echo "curl -X POST \"$CHOREO_URL/health/signup\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d @test-signup-payload.json"
