const WebSocket = require('ws');
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

/**
 * GoTTY WebSocket Test Script
 * 
 * Tests WebSocket connection to GoTTY terminal server with command execution.
 * Requires GOTTY_DOMAIN and GOTTY_CREDENTIAL in .env file.
 * 
 * Usage: node test/test-gotty-command.js
 */

// Configuration from environment
const DOMAIN = process.env.GOTTY_DOMAIN || 'localhost';
const WS_URL = `wss://${DOMAIN}/ws`;
const CREDENTIAL = process.env.GOTTY_CREDENTIAL || 'terminal:your-token-here';

// Create Basic Auth header
const auth = Buffer.from(CREDENTIAL).toString('base64');

console.log('🔌 Testing GoTTY WebSocket Connection');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('URL:', WS_URL);
console.log('Auth: Basic ****** (from .env GOTTY_CREDENTIAL)');
console.log('');

const ws = new WebSocket(WS_URL, {
    headers: {
        'Authorization': `Basic ${auth}`
    },
    rejectUnauthorized: true
});

const MSG_INPUT = '1';
const MSG_RESIZE = '3';
const MSG_PING = '2';

let receivedOutput = false;
let commandsSent = 0;
let pingInterval;

// Setup message handler BEFORE connection opens
ws.on('message', (data) => {
    /**
     * GoTTY Protocol:
     * - Binary messages with first byte as type indicator
     * - Type '0' (0x30) = input/output data (base64-encoded)
     * - Type '1' (0x31) = output (base64-encoded)
     * - Type '2' (0x32) = ping/pong
     * - Remaining bytes after type byte are base64-encoded content
     */

    if (Buffer.isBuffer(data) || data instanceof ArrayBuffer) {
        const buffer = Buffer.isBuffer(data) ? data : Buffer.from(data);

        console.log('📨 Raw message received, length:', buffer.length, 'first byte:', buffer[0], '(0x' + buffer[0].toString(16) + ')');

        if (buffer.length > 1) {
            const msgType = buffer[0];
            const content = buffer.slice(1);

            if (msgType === 0x30) {
                console.log('ℹ️ Received server init payload');
            }

            // Handle terminal output (type '1' contains base64-encoded data)
            if (msgType === 0x31) {
                try {
                    const base64Data = content.toString('utf-8');
                    const decoded = Buffer.from(base64Data, 'base64').toString('utf-8');

                    if (decoded.trim()) {
                        receivedOutput = true;
                        console.log('📥 Output:', JSON.stringify(decoded.trim()));
                    }
                } catch (e) {
                    // Ignore decode errors for control messages
                }
            }
        }
    }
});

ws.on('open', () => {
    console.log('✅ WebSocket connected successfully!');
    console.log('');

    // 1. Send handshake immediately
    const initMessage = JSON.stringify({ Arguments: '', AuthToken: CREDENTIAL });
    console.log('🤝 Sending handshake:', initMessage.substring(0, 50) + '...');
    ws.send(initMessage);

    // 2. Send resize immediately after handshake (no delay)
    console.log('📐 Sending resize payload');
    ws.send(MSG_RESIZE + JSON.stringify({ columns: 80, rows: 24 }));

    // 3. Setup ping interval
    pingInterval = setInterval(() => {
        console.log('💓 Sending ping');
        ws.send(MSG_PING);
    }, 30000);

    // 4. Send commands after a brief delay to allow terminal to initialize
    const sendCommand = (label, command, delay) => {
        setTimeout(() => {
            commandsSent++;
            console.log(`📤 Command ${label}: ${command}`);
            ws.send(MSG_INPUT + command + '\r');
        }, delay);
    };

    sendCommand('1', 'pwd', 400);
    sendCommand('2', 'whoami', 800);
    sendCommand('3', 'echo "GoTTY WebSocket Test Successful!"', 1200);
    sendCommand('4', 'exit', 2000);
});

ws.on('error', (error) => {
    console.error('');
    console.error('❌ WebSocket error:', error.message);
    console.error('');
    console.error('Troubleshooting:');
    console.error('  1. Check GOTTY_DOMAIN in .env file');
    console.error('  2. Check GOTTY_CREDENTIAL in .env file');
    console.error('  3. Verify GoTTY service is running:');
    console.error('     sudo systemctl status gottyconnect');
    console.error('  4. Check nginx is proxying /ws endpoint');
    console.error('');
});

ws.on('close', (code, reason) => {
    if (pingInterval) {
        clearInterval(pingInterval);
    }
    console.log('');
    console.log('🔌 WebSocket closed');
    console.log('   Code:', code);
    console.log('   Reason:', reason.toString() || 'Normal closure');
    console.log('   Commands sent:', commandsSent);
    console.log('   Output received:', receivedOutput ? 'Yes ✅' : 'No ❌');
    console.log('');
    console.log('📊 Close Code Reference:');
    console.log('   1000 = Normal closure');
    console.log('   1001 = Going away');
    console.log('   1006 = Abnormal closure (no close frame)');
    console.log('   1011 = Server error');
    console.log('');

    if (receivedOutput) {
        console.log('✅ SUCCESS: Commands executed and output received!');
        console.log('');
        process.exit(0);
    } else {
        console.log('⚠️  WARNING: No output received from terminal');
        console.log('');
        console.log('Possible issues:');
        console.log('  - Commands may have executed but output not captured');
        console.log('  - Check GoTTY logs: sudo journalctl -u gottyconnect -n 50');
        console.log('  - Verify WebSocket connection in browser DevTools');
        console.log('');
        process.exit(1);
    }
});

// Timeout after 10 seconds to allow command execution
setTimeout(() => {
    console.log('');
    console.log('⏰ Test timeout - closing connection');
    if (pingInterval) {
        clearInterval(pingInterval);
    }
    ws.close();
}, 10000);
