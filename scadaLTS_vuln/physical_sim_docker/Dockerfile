FROM ubuntu:22.04

USER root
WORKDIR /root/
RUN apt-get update && \
    apt-get -y install python3-pip python3-venv

WORKDIR /home/
# Copy the python script to the image
COPY physics_sim.py ./
COPY config.json ./
COPY requirements.txt ./
COPY run.sh ./
RUN chmod +x run.sh

# Making a venv environment
RUN python3 -m venv .venv
RUN .venv/bin/pip3 install -r requirements.txt

# launch of the python script
CMD ["./run.sh"]
#CMD ["tail","-f","/dev/null"]
