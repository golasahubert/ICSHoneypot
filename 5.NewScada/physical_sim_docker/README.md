## Description
A Docker container running a Python physical process simulator, based on SciPy library, that models a water treatment system in a lightweight manner.

## Main files description
- config.json: A JSON file which contains the data to initialize the simulator, such as udp servers of the PSM interfaces network info, PLC registers info and the simulation time.
- physics_sim.py: A Python program that simulates the physical process of the system using the SciPy library to solve a system of Ordinary Differential Equations (ODEs).
- requirements.txt: A text file containing the Python libraries to be installed.
- run.sh: A Bash script that launches the Python program.

## How to implement a personal simulated physical process
- Modify the config.json file to:
    - Set a desidered simulation time.
    - Set the network info related to the external sources (e.g. PLC brokers UDP servers), which receive the simulated values and send the updated actuators states.
    - Set the input (sensors) and output (actuators) registers of the external sources.
    - Set a desired initial state modifying the input and output registers values. 
- Modify the first-order ODEs system contained in function mydiff() of physics_sim.py.
