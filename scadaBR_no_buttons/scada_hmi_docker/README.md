## Description
A Docker container containing the SCADA HMI of the system, implemented through ScadaBR.

## Main files description
- dataHMI.txt: A text file containing the data sources and the graphical view of the system.
- loaddata.py: A Python script that automate the loading of the "dataHMI.txt" file inside ScadaBR.
- requirements.txt: A text file containing the Python libraries to be installed.
- run.sh: A Bash script that initializes and runs ScadaBR.

## Important notes
- The auto-loading of data inside ScadaBR may take few time (~3 minutes).
- check the latest version of chromedriver and modify the CHROMEDRIVER_VERSION variable inside the Dockerfile.
```dockerfile
  ENV CHROMEDRIVER_VERSION=130.0.6723.69
```
