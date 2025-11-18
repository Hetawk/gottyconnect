#!/bin/bash
# Load environment variables from local .env file
if [ -f .env ]; then
    source .env
else
    echo "❌ Error: .env file not found. Copy .env.example to .env and configure."
    exit 1
fi

echo "🧪 Testing GoTTY Terminal Server"
echo ""

# Test 1: Health check
echo "1️⃣  Health check..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://${GOTTY_DOMAIN}/health 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Health check OK"
else
    echo "   ❌ Health check failed (code: $HTTP_CODE)"
fi

# Test 2: Public endpoint with valid token (NO POPUP!)
echo ""
echo "2️⃣  Public endpoint (iframe-friendly)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://${GOTTY_DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Public endpoint works (NO AUTH POPUP)"
else
    echo "   ❌ Public endpoint failed (code: $HTTP_CODE)"
fi

# Test 3: Public endpoint with invalid token (should fail)
echo ""
echo "3️⃣  Token validation..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://${GOTTY_DOMAIN}/public?token=invalid" 2>/dev/null)
if [ "$HTTP_CODE" = "401" ]; then
    echo "   ✅ Invalid token rejected (401)"
else
    echo "   ⚠️  Unexpected code: $HTTP_CODE"
fi

# Test 4: Direct access with Basic Auth
echo ""
echo "4️⃣  Basic Auth (direct access)..."
GOTTY_CREDENTIAL="${GOTTY_CREDENTIAL:-terminal:${GOTTY_AUTH_TOKEN}}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${GOTTY_CREDENTIAL}" \
    https://${GOTTY_DOMAIN} 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Basic Auth works"
else
    echo "   ⚠️  Basic Auth code: $HTTP_CODE"
fi

echo ""
echo "5️⃣  Service status:"
sudo systemctl status gottyconnect.service --no-pager -l | head -8

echo ""
echo "✅ Test complete!"
echo ""
echo "🔗 Connection Info:"
echo "   Public (NO POPUP): https://${GOTTY_DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}"
echo "   Direct (has popup): https://${GOTTY_DOMAIN}"
echo "   WebSocket: wss://${GOTTY_DOMAIN}/ws"
echo ""
echo "📋 For iframe embedding (recommended):"
echo "   <iframe src=\"https://${GOTTY_DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}\"></iframe>"
