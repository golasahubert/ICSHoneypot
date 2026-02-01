FROM ubuntu:22.04

USER root
WORKDIR /root/

RUN apt-get update && \
    apt-get -y install python3-pip python3-venv git sudo

WORKDIR /home/
RUN git clone https://github.com/thiagoralves/OpenPLC_v3.git

WORKDIR /home/OpenPLC_v3/
# Stable version of OpenPLC commit:a283d0dbac813116babdf81c53144c4d455edf49 (dec 2023)
#RUN git checkout a283d0dbac813116babdf81c53144c4d455edf49
RUN sudo ./install.sh linux

# copy files into docker container
COPY main.py webserver/core/psm/
COPY run.sh ./
#give permission to run.sh
RUN chmod +x run.sh
COPY PLC1.st scripts/
COPY PLC1.st.dbg scripts/
COPY config.json ./
COPY requirements.txt ./
RUN python3 -m venv .venv
RUN .venv/bin/pip3 install -r requirements.txt
# To get the right configuration from config.json
RUN echo -n "plc1" > plc_name.txt

# lighttpd and snap7
WORKDIR /home/
RUN apt-get update && \
    apt-get -y install lighttpd
RUN git clone https://github.com/sefcom/honeyplc.git
COPY ./web /var/www/html
COPY lighthttpd.conf /etc/lighttpd/lighttpd.conf
RUN cd /home/honeyplc/snap7/build/bin/x86_64-linux/ && cp libsnap7.so-1200 /usr/lib/libsnap7.so

WORKDIR /home/OpenPLC_v3/

EXPOSE 502
EXPOSE 8080
EXPOSE 102
EXPOSE 80

CMD ["./run.sh"]
#CMD ["tail", "-f", "/dev/null"]
