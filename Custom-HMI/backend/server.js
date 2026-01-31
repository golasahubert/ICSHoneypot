const express = require('express');
const cors = require('cors');
const ModbusRTU = require('modbus-serial');

const app = express();
app.use(cors());
app.use(express.json());

// PlC Config
const plcs = [
    { name: 'PLC1 (T-201 Control)', host: 'plc1', port: 502, client: new ModbusRTU() },
    { name: 'PLC2 (T-202 Monitor)', host: 'plc2', port: 502, client: new ModbusRTU() },
    { name: 'PLC3 (T-203 Control)', host: 'plc3', port: 502, client: new ModbusRTU() }
];

// Structure to store data read from all PLCs
let systemState = {};

// Function to connect a single PLC client
function connectClient(plc) {
    console.log(`[${plc.name}] Attempting to connect to ${plc.host}:${plc.port}...`);
    
    // Remove all previous listeners
    plc.client.removeAllListeners();

    plc.client.connectTCP(plc.host, { port: plc.port })
        .then(() => {
            console.log(`[${plc.name}] Successfully connected.`);
            plc.client.setID(1);
        })
        .catch((err) => {
            console.error(`[${plc.name}] Connection failed: ${err.message}. Retrying in 5 seconds...`);
            setTimeout(() => connectClient(plc), 5000);
        });
    
    // Manage errors
    plc.client.on('error', (err) => {
        console.error(`[${plc.name}] Modbus Error: ${err.message}`);
        if (plc.client.isOpen) {
            plc.client.close(() => {});
        }
    });

    // Manage the connection closure
    plc.client.on('close', () => {
        console.log(`[${plc.name}] Connection closed. Attempting to reconnect...`);
        if (!plc.client.isOpen) {
            setTimeout(() => connectClient(plc), 5000);
        }
    });
}

// Connect to all PLCs
plcs.forEach(connectClient);

// Function to read data from all PLCs
async function pollAllPlcs() {
    for (const plc of plcs) {
        // If the client is not connected, don't try to read data
        if (!plc.client.isOpen) {
            // Initialize data to a default state if not connected
            if (!systemState[plc.name] || systemState[plc.name].status !== 'Disconnected') {
                console.warn(`[${plc.name}] Skipping poll, client not connected.`);
                systemState[plc.name] = { status: 'Disconnected', data: {} };
            }
            continue;
        }

        try {
            let plcData = {};

            // Read common data from input registers
            const levelReg = await plc.client.readInputRegisters(0, 1);
            plcData.level = levelReg.data[0];

            // Reading data specific to each PLC
            if (plc.name.includes('T-201')) {
                const coils = await plc.client.readCoils(0, 5);
                plcData.pump = coils.data[0];
                plcData.valve = coils.data[1];
                plcData.request = coils.data[2];
                plcData.underflow = coils.data[3];
                plcData.overflow = coils.data[4];
            } else if (plc.name.includes('T-202')) {
                const coils = await plc.client.readCoils(0, 3);
                plcData.request = coils.data[0];
                plcData.open_req = coils.data[1];
                plcData.close_req = coils.data[2];
            } else if (plc.name.includes('T-203')) {
                const coils = await plc.client.readCoils(0, 3);
                plcData.pump = coils.data[0];
                plcData.low = coils.data[1];
                plcData.high = coils.data[2];
            }
            
            // Update the status to 'Connected'
            systemState[plc.name] = { status: 'Connected', data: plcData };

        } catch (err) {
            console.error(`[${plc.name}] Error reading data: ${err.message}`);
            // In case of read error, set status to 'Error'
            systemState[plc.name] = { status: 'Error', data: {} };
            // Close the connection if the read fails
            if (plc.client.isOpen) {
                plc.client.close(() => {});
            }
        }
    }
}

// Update every second
setInterval(pollAllPlcs, 1000);

// Endpoint API for providing data to the frontend
app.get('/api/data', (req, res) => {
    res.json(systemState);
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`HMI Backend listening on port ${PORT}`);
});