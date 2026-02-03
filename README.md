# Collection of lightweight ICS Honeypots

In this folder there are 4 versions of projects with OpenPLCs imitating PLCs used in SWaT (Simplified Water Treatment). There is also python script to introduce realistic simulation of physcial processes between these tanks.
There are 3 tanks - PLCs 1,2,3. Water flows from the biggest tank to middle, then to smallest tank. This simulates real world process.



## 1. Custom HMI (singapore-001)

This HMI is fully custom HMI based on Tailwind CSS and Node.js/Express.js, For more information head to folder of this HMI. This HMI does not have any  interactive features (no login/no buttons) which encourages attackers to dig deeper into the exposed PLC2 (modbus)

<img width="1807" height="901" alt="image" src="https://github.com/user-attachments/assets/6d63dcff-e12c-43e0-ad19-53d5cf418d9c" />

## 2. ScadaBR (singapore-002)

This HMI uses ScadaBR in its latest version, there are also buttons which attacker can use to play with the system

<img width="1209" height="702" alt="image" src="https://github.com/user-attachments/assets/88b69559-a7c9-4617-8375-68765b8c711b" />

## 3. ScadaBR without buttons (singapore-003)

Same as before, only difference is that there are no buttons.

<img width="1209" height="702" alt="image" src="https://github.com/user-attachments/assets/673d74a1-616a-40fa-ae14-117d9b2d3e5d" />


## 4. ScadaLTS v2.7.4

This HMI uses ScadaLTS v2.7.4 which is vulnerable to https://nvd.nist.gov/vuln/detail/CVE-2023-33472

<img width="1209" height="702" alt="image" src="https://github.com/user-attachments/assets/57bec638-278c-4271-88c6-ed1e6b39d264" />



## Common Features 

To run any system please use bash script 
```console
sudo bash build_system.sh
```
which scripts are located in every folder. This script uses docker-compose.yml file to define properties as names, addressing, ports for each component. Those properties are common for HMIs 2-4. This script first cleans up previous ALL docker networks and containers, and build the system. This script can be used after compromising the system to build system once over. After builidng the system, this scripts performs automatic import of data (automation folder) dataHMI.txt contains json of all properties that are imported. Then system restarts the OpenPLCs (required).

Stopping and starting the system is done via stop/start_system.sh script.

Users defined in 2-4 are admin/admin and user/user123.

Each 1-4 has PLC2 Tank modbus port exposed 502.

Each System has also nginx proxy configured in a way so that after entering the IP address, it redirects to HMI url

## Logging 

Logging is done by running tcpdump which generates pcap files and later they are donwloaded by external server. There are also nginx logs, but since we want to focus on MODBUS traffic, they are not used

## Alerting 

ICSAgent is and Agent that needs to be configured and will send a Telegram notification whenever system is compromised or not working. Refer to ICSAgent repo for more information

