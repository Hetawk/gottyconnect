/**
 * Test the xterm API endpoint with real command execution
 */

// Use andvpn .env which has TTYD keys from xterm project
require('dotenv').config({ path: require('path').join(__dirname, '..', '..', 'andvpn', '.env') });

const API_URL = 'http://localhost:3001/api/ttyd/execute'; // xterm runs on 3001
const API_KEY = 'test-system-key-12345'; // Use test key for now

async function testCommand(command) {
    console.log(`\n🧪 Testing: ${command}`);
    console.log(`API URL: ${API_URL}`);

    try {
        const response = await fetch(API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': API_KEY
            },
            body: JSON.stringify({ command })
        });

        const data = await response.json();

        console.log(`\nStatus: ${response.status}`);
        console.log(`Success: ${data.success}`);

        if (data.output) {
            console.log(`\n📤 Output:\n${data.output}`);
        }

        if (data.error) {
            console.log(`\n❌ Error: ${data.error}`);
        }

        return data;
    } catch (error) {
        console.error(`\n❌ Request failed:`, error.message);
        return null;
    }
}

(async () => {
    console.log('🚀 xterm API Test Suite\n');
    console.log('='.repeat(50));

    // Test 1: Simple pwd
    await testCommand('pwd');

    // Test 2: List files
    await testCommand('ls -la');

    // Test 3: Check uptime
    await testCommand('uptime');

    console.log('\n' + '='.repeat(50));
    console.log('✅ Test suite complete\n');
})();
