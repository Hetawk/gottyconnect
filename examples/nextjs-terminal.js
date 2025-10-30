// Example Next.js API route for executing terminal commands
// Save as: pages/api/terminal/execute.js or app/api/terminal/execute/route.js

// For Pages Router (pages/api/terminal/execute.js):
import { WebSocket } from 'ws';

export default async function handler(req, res) {
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const { command } = req.body;

    if (!command) {
        return res.status(400).json({ error: 'Command is required' });
    }

    try {
        const ws = new WebSocket(process.env.TTYD_URL, {
            headers: {
                'X-Auth-Token': process.env.TTYDCONNECT_AUTH_TOKEN,
            },
        });

        let output = '';

        ws.on('open', () => {
            ws.send(command + '\n');
        });

        ws.on('message', (data) => {
            output += data.toString();
        });

        ws.on('error', (error) => {
            console.error('WebSocket error:', error);
            res.status(500).json({ error: 'Failed to connect to terminal' });
        });

        // Wait for output then close
        setTimeout(() => {
            ws.close();
            res.status(200).json({ success: true, output });
        }, 2000);

    } catch (error) {
        console.error('Terminal error:', error);
        res.status(500).json({ error: 'Failed to execute command' });
    }
}

// For App Router (app/api/terminal/execute/route.js):
// import { NextResponse } from 'next/server';
// import { WebSocket } from 'ws';
// 
// export async function POST(request) {
//     const { command } = await request.json();
//     
//     // Same WebSocket logic as above...
//     
//     return NextResponse.json({ success: true, output });
// }
