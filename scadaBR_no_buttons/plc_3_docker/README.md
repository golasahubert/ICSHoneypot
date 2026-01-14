## Description
A Docker container running a virtual PLC, emulated using OpenPLC, which monitors and controls the sensors and actuators of Tank T-203. More precisely, the PLC controls a pump (P-102), which allows the Tank T-203 water to be pumped back into the Tank T-202.

## Main files description
- config.json: A JSON file containing system information to initialize the PSM broker.
- main.py: A Python program that implements the PSM broker to interact with the Python simulator of the physical process and the virtla PLC's registers. The PSM (Python SubModule) is an OpenPLC module that enables interaction with external systems, as long as Python drivers exist.
- PLC3.st: A Structured Text (ST) file containing the PLC3's control logic.
- requirements.txt: A text file containing the Python libraries to be installed.
- run.sh: A Bash script that initializes and runs OpenPLC.
