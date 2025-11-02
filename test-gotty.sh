#!/bin/bash
echo "🧪 Testing GoTTY Terminal Server"
echo ""

# Test 1: Health check
echo "1️⃣  Health check..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://ttydconnect.ekddigital.com/health 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Health check OK"
else
    echo "   ❌ Health check failed (code: $HTTP_CODE)"
fi

# Test 2: Token authentication
echo ""
echo "2️⃣  Token authentication..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Auth-Token: 8bd628f7b79f35c6cdd4de3d708647a61112bf302b95b9f0a5e37e2cd0e4e1d5" \
    https://ttydconnect.ekddigital.com 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Token auth works"
else
    echo "   ❌ Token auth failed (code: $HTTP_CODE)"
fi

# Test 3: Without token (should fail)
echo ""
echo "3️⃣  Auth protection..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    https://ttydconnect.ekddigital.com 2>/dev/null)
if [ "$HTTP_CODE" = "401" ]; then
    echo "   ✅ Protected (401 without token)"
else
    echo "   ⚠️  Unexpected code: $HTTP_CODE"
fi

echo ""
echo "4️⃣  Service status:"
sudo systemctl status gottyconnect.service --no-pager -l | head -8

echo ""
echo "✅ Test complete!"
echo ""
echo "🔗 Connection Info:"
echo "   URL: https://ttydconnect.ekddigital.com"
echo "   WebSocket: wss://ttydconnect.ekddigital.com/ws"
echo "   Auth Token: 8bd628f7b79f35c6cdd4de3d708647a61112bf302b95b9f0a5e37e2cd0e4e1d5"
