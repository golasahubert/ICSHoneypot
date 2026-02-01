## Description
A Docker container running a virtual PLC, emulated using OpenPLC, which monitors and controls the sensors and actuators of Tank T-201. Specifically, the PLC controls:
- A valve (MV-301) that connects Tank T-201 to Tank T-202;
- A pump (P-101) that allows Tank T-201 to be filled.

## Main files description
- config.json: A JSON file containing system information to initialize the PSM broker.
- main.py: A Python program that implements the PSM broker to interact with the Python simulator of the physical process and the virtual PLC's registers. The PSM (Python SubModule) is an OpenPLC module that enables interaction with external systems, as long as Python drivers exist.
- PLC1.st: A Structured Text (ST) file containing the PLC1's control logic.
- requirements.txt: A text file containing the Python libraries to be installed.
- run.sh: A Bash script that initializes and runs OpenPLC.
