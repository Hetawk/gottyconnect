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

let receivedOutput = false;
let commandsSent = 0;

ws.on('open', () => {
    console.log('✅ WebSocket connected successfully!');
    console.log('');

    // GoTTY protocol: Send commands with type '0' (input)
    // Format: '0' + command + '\n'

    setTimeout(() => {
        commandsSent++;
        console.log('📤 Command 1: pwd');
        ws.send('0pwd\n');
    }, 300);

    setTimeout(() => {
        commandsSent++;
        console.log('📤 Command 2: whoami');
        ws.send('0whoami\n');
    }, 800);

    setTimeout(() => {
        commandsSent++;
        console.log('📤 Command 3: echo "GoTTY WebSocket Test Successful!"');
        ws.send('0echo "GoTTY WebSocket Test Successful!"\n');
    }, 1300);

    setTimeout(() => {
        commandsSent++;
        console.log('📤 Command 4: date');
        ws.send('0date\n');
    }, 1800);
});

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

        if (buffer.length > 1) {
            const msgType = buffer[0];
            const content = buffer.slice(1);

            // Handle terminal output (types '0' and '1' contain base64-encoded data)
            if (msgType === 0x30 || msgType === 0x31) {
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
    console.log('');
    console.log('🔌 WebSocket closed');
    console.log('   Code:', code);
    console.log('   Reason:', reason.toString() || 'Normal closure');
    console.log('   Commands sent:', commandsSent);
    console.log('   Output received:', receivedOutput ? 'Yes ✅' : 'No ❌');
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

// Timeout after 5 seconds
setTimeout(() => {
    console.log('');
    console.log('⏰ Test timeout - closing connection');
    ws.close();
}, 5000);
