const WebSocket = require('ws');
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const DOMAIN = process.env.GOTTY_DOMAIN;
const CREDENTIAL = process.env.GOTTY_CREDENTIAL;
const WS_URL = `wss://${DOMAIN}/ws`;
const auth = Buffer.from(CREDENTIAL).toString('base64');

console.log('🔌 Simple GoTTY Test');
console.log('URL:', WS_URL);
console.log('');

const ws = new WebSocket(WS_URL, {
    headers: { 'Authorization': `Basic ${auth}` },
    rejectUnauthorized: true
});

let messageCount = 0;
let commandSent = false;

ws.on('message', (data) => {
    messageCount++;
    const buffer = Buffer.from(data);
    const msgType = String.fromCharCode(buffer[0]);
    const payload = buffer.slice(1).toString('utf-8');

    console.log(`📨 Message ${messageCount}: type='${msgType}' (0x${buffer[0].toString(16)}), length=${payload.length}`);

    if (msgType === '1' && payload) {
        // Terminal output - base64 decode it
        try {
            const decoded = Buffer.from(payload, 'base64').toString('utf-8');
            console.log('   Output:', decoded.replace(/\r?\n/g, '\\n'));
        } catch (e) {
            console.log('   Raw:', payload.substring(0, 100));
        }
    } else if (payload.length < 200) {
        console.log('   Payload:', payload);
    }

    // After receiving window title message (type '2'), terminal is ready
    if (msgType === '2' && !commandSent) {
        commandSent = true;
        console.log('\n→ Sending command\n');

        // Type '0' + raw string for stdin
        setTimeout(() => {
            ws.send('0pwd\r');
            console.log('Sent: pwd');
        }, 100);
    }
});

ws.on('open', () => {
    console.log('✅ Connected\n');

    // Send handshake
    ws.send(JSON.stringify({ Arguments: '', AuthToken: CREDENTIAL }));
    console.log('→ Sent handshake\n');

    // Send resize (type '2' not '3'!)
    ws.send('2' + JSON.stringify({ columns: 80, rows: 24 }));
    console.log('→ Sent resize\n');

    // Don't send command immediately - wait for init messages first

    // Close after 5 seconds
    setTimeout(() => {
        console.log('⏰ Closing connection');
        ws.close();
    }, 5000);
});

ws.on('error', (err) => console.error('❌ Error:', err.message));
ws.on('close', (code) => {
    console.log(`\n🔌 Closed (code ${code}), received ${messageCount} messages`);
    process.exit(code === 1000 ? 0 : 1);
});
