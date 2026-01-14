# Simplified Secure Water Treatment (SSWaT) system testbed with a Python physical process simulator

## Description
This testbed has been specifically designed to evaluate a SciPy-based physical process simulator, developed to replace the heavyweight MATLAB Simulink simulator within the HoneyICS honeynet, created by Marco Lucchese et al. It replicates an Industrial Control System (ICS) up to the Supervisory level of the Purdue model for a three-tank water treatment system. The architecture, technologies, and tools of this testbed are inspired by the HoneyICS honeynet. The simulated physical process is a simplified version of the Secure Water Treatment (SWaT) testbed, originally developed by iTrust, and it is designed to assess the SciPy-based simulator in a hydraulic context with a relatively slow system.

The testbed consists of five Docker containers, which are as follows:
- SCADA HMI container: This container runs an instance of ScadaBR, which implements a SCADA HMI, allowing users to visualize and interact with the simulated process.
- Three Virtual PLC containers: Each container runs a virtual PLC implemented through OpenPLC. These PLCs monitor sensors and control actuators within the simulated tank system. Additionally, the PLC-2 container includes a Python broker to simulate communication between PLC-2 and PLC-1.
- Physical process simulator container: This container runs a Python physical process simulator that uses the SciPy library and first-order differential equations to model the physical processes occurring in the water treatment tank system.

## Physical process
![phy_proc_sswat](/materials/images/simplified_SWAT_system.png)
**Figure 1**: Simplified SWaT system physical process

## Testbed architecture
![arch_sswat](/materials/images/architecture_SSWAT_testbed_scipy.png)
**Figure 2**: Architecture simplified SWaT system testbed

## SciPy-based physical process simulator lightweight property evaluation
To facilitate a more direct comparison of resource consumption between the SciPy-based simulator and the Simulink-based simulator, another version of the SWaT testbed was created using the Simulink-based physical process simulator. This testbed version is contained in folder "/Evaluation_materials/Lightweight". As we can see in **Figure 3** and **Figure 4**, the SciPy-based simulator achieves a substantial reduction in resource usage, with RAM consumption decreasing by several gigabytes.
![res_scipy](/materials/images/SSWaT_resources.png)
**Figure 3**: Simplified SWaT SciPy-based simulator resources consuption
![res_sim](/materials/images/matlab_sim_res.png)
**Figure 4**: Simplified SWaT Simulink-based simulator resources consuption

## SciPy-based physical process simulator interactivity property evaluation
To evaluate the interactivity property of the SciPy-based simulator, a Python script was developed. This script establishes a Modbus connection to continuously overwrite the value in the PLC-1 output register that controls the status of the Tank 1 pump, forcing it to remain active. This Python script is contained inside "/Evaluation_materials/Interactivity". **Figure 5** shows an instance of the genuine simulated physical process for Tank 1, while **Figure 6** illustrates the simulator’s response to the manipulation of the physical process by the Python script.
![tank_1_before](/materials/images/genuine_tank_1.png)
**Figure 5**: Genuine physical process Tank 1
![tank_2_after](/materials/images/manipulated_tank_1.png)
**Figure 6**: Manipulated physical process Tank 1

## Main file descriptions
- build_system.sh: A Bash script that builds docker images and runs the docker containers of the system (PLCs, SCADA HMI and Python-based simulator).
- start_system.sh: A Bash script that starts docker containers of the system.
- stop_system.sh: A Bash script that stops docker containers of the system.

## Docker images building and containers running

```bash
  sh ./build_system.sh
```

## Starting the system

```bash
  sh ./start_system.sh
```

## Stopping the system

```bash
  sh ./stop_system.sh
```

## Important note about OpenPLC instances
When you start the system for the first time you have to click on "Save changes" button in the "Hardware" page for each OpenPLC istance. Then you have to restart the system.
