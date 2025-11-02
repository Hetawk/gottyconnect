const WebSocket = require('ws');
require('dotenv').config();

// Configuration from environment
const WS_URL = process.env.GOTTY_WS_URL || 'wss://localhost/ws';
const CREDENTIAL = process.env.GOTTY_CREDENTIAL || 'username:password';
const [USERNAME, PASSWORD] = CREDENTIAL.split(':');

// Create auth header
const auth = Buffer.from(`${USERNAME}:${PASSWORD}`).toString('base64');

console.log('🔌 Testing GoTTY WebSocket with command execution...');
console.log('URL:', WS_URL);
console.log('Auth:', `${USERNAME}:****`);
console.log('');

const ws = new WebSocket(WS_URL, {
    headers: {
        'Authorization': `Basic ${auth}`
    }
});

let receivedOutput = false;

ws.on('open', () => {
    console.log('✅ WebSocket connected!');
    console.log('');

    // Send authentication (GoTTY protocol)
    console.log('📤 Sending authentication...');
    ws.send(JSON.stringify({
        AuthToken: `${USERNAME}:${PASSWORD}`
    }));

    // Wait a bit then send commands
    setTimeout(() => {
        console.log('📤 Sending command: pwd');
        ws.send('0pwd\n');
    }, 500);

    setTimeout(() => {
        console.log('📤 Sending command: ls -la');
        ws.send('0ls -la\n');
    }, 1000);

    setTimeout(() => {
        console.log('📤 Sending command: echo "SUCCESS: GoTTY is working!"');
        ws.send('0echo "SUCCESS: GoTTY is working!"\n');
    }, 1500);

    setTimeout(() => {
        console.log('📤 Sending command: whoami');
        ws.send('0whoami\n');
    }, 2000);
});

ws.on('message', (data) => {
    // GoTTY sends binary data
    if (Buffer.isBuffer(data) || data instanceof ArrayBuffer) {
        const buffer = Buffer.isBuffer(data) ? data : Buffer.from(data);

        if (buffer.length > 0) {
            const msgType = String.fromCharCode(buffer[0]);
            const content = buffer.slice(1);

            console.log(`📋 Message type: '${msgType}' (byte: ${buffer[0]}, length: ${buffer.length})`);

            if (msgType === '1' || buffer[0] === 0x31) {
                // Output from terminal (0x31 = '1')
                try {
                    const output = content.toString('utf-8');
                    if (output.trim()) {
                        receivedOutput = true;
                        console.log('📥 Terminal output:', JSON.stringify(output));
                    }
                } catch (e) {
                    console.log('📥 Raw output (hex):', content.toString('hex'));
                }
            } else if (msgType === '0' || buffer[0] === 0x30) {
                // Input echo OR output (GoTTY uses '0' for both)
                const base64Data = content.toString('utf-8');
                if (base64Data.trim()) {
                    try {
                        const decoded = Buffer.from(base64Data, 'base64').toString('utf-8');
                        if (decoded.trim()) {
                            receivedOutput = true;
                            console.log('� Terminal data:', JSON.stringify(decoded));
                        }
                    } catch (e) {
                        console.log('🔄 Raw data:', JSON.stringify(base64Data.substring(0, 50)));
                    }
                }
            }
        }
    } else {
        const msg = data.toString();
        console.log('� String message:', msg.substring(0, 100));
    }
});

ws.on('error', (error) => {
    console.error('❌ WebSocket error:', error.message);
});

ws.on('close', (code, reason) => {
    console.log('');
    console.log('🔌 WebSocket closed');
    console.log('   Code:', code);
    console.log('   Reason:', reason.toString() || 'No reason provided');
    console.log('');

    if (receivedOutput) {
        console.log('✅ SUCCESS: Commands executed and output received!');
    } else {
        console.log('⚠️  WARNING: No output received from terminal');
    }

    process.exit(receivedOutput ? 0 : 1);
});

// Timeout after 10 seconds
setTimeout(() => {
    console.log('');
    console.log('⏰ Timeout - closing connection');
    ws.close();
}, 10000);
