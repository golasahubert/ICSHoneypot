## Description
A Docker container running a virtual PLC, emulated using OpenPLC, that monitors the water level sensor of Tank T-202. The primary function of this PLC is to determine when to send a signal, via Modbus, to PLC-1 to open the valve (MV-301).

## Main files description
- config.json: A JSON file containing system information to initialize the PSM broker;
- main.py: A Python program that implements the PSM broker to interact with the Python simulator of the physical process and the virtual PLC's registers. The PSM (Python SubModule) is an OpenPLC module that enables interaction with external systems, as long as Python drivers exist;
- PLC2.st: A Structured Text (ST) file containing the PLC1's control logic;
- requirements.txt: A text file containing the Python libraries to be installed;
- run.sh: A Bash script that initializes and runs OpenPLC;
- comm_modbus.py: A Python script that implements a simple broker, enabling PLC-2 to send signals to PLC-1 via Modbus.
