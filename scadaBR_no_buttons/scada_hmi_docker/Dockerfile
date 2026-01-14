FROM ubuntu:22.04

# please review all the latest versions here:
# https://googlechromelabs.github.io/chrome-for-testing/
ENV CHROMEDRIVER_VERSION=130.0.6723.69

USER root

RUN apt update && \
    apt-get -y install sudo git python3-pip wget unzip

WORKDIR /home/
RUN git clone https://github.com/thiagoralves/ScadaBR_Installer.git
COPY requirements.txt ./
RUN pip3 install -r requirements.txt

WORKDIR /home/ScadaBR_Installer/
RUN sudo ./install_scadabr.sh

WORKDIR /home/
COPY run.sh ./
RUN chmod +x run.sh
# Installing chrome and chromedriver in order to use selenium
RUN sudo rm -r /var/lib/apt/lists/* && sudo apt update
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN apt-get install ./google-chrome-stable_current_amd64.deb -y --fix-missing
RUN wget https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/$CHROMEDRIVER_VERSION/linux64/chromedriver-linux64.zip \
  && unzip chromedriver-linux64.zip && rm -dfr chromedriver_linux64.zip \
  && mv ./chromedriver-linux64/chromedriver /usr/bin/chromedriver \
  && chmod +x /usr/bin/chromedriver

EXPOSE 502
EXPOSE 8080
EXPOSE 9090

CMD ["sh","./run.sh"]
#make the container run infinitely
#CMD ["tail", "-f", "/dev/null"]

