FROM ubuntu:latest

MAINTAINER George Gilman

#Create default settings
ENV IGSERVER noam.aprs2.net
ENV BEACON_DELAY 1
ENV BEACON_EVERY 10
ENV BEACON_SYMBOL R\&
ENV COMMENT "Docker APRS IGate"
ENV LATITUDE 0.0
ENV LONGITUDE 0.0
ENV APRS_FREQUENCY 144.39M

RUN apt-get update  && \
	apt-get upgrade -y && \
	apt-get install git gcc g++ make cmake -y  && \
	apt-get install	libasound2-dev libudev-dev libavahi-client-dev -y && \
	apt-get install libusb-1.0-0-dev -y

RUN mkdir /etc/modprobe.d
RUN  echo "blacklist rtl2832\n\
blacklist r820t\n\
blacklist rtl2830\n\
blacklist dvb_usb_rtl28xxu" > /etc/modprobe.d/rtlsdr-blacklist.conf

RUN cd ~ \
&& git clone https://gitea.osmocom.org/argilo/rtl-sdr.git \
&& cd rtl-sdr \
&& mkdir build \
&& cd build \
&& cmake ../ \
&& make \
&& make install \
&& ldconfig

RUN cd ~ \
&& git clone https://www.github.com/wb2osz/direwolf \
&& cd direwolf \
&& mkdir build && cd build \
&& cmake .. \
&& make -j4 \
&& make install \
&& make install-conf

COPY sdr-igate.conf.template ./
COPY run.sh ./

CMD ./run.sh
# ./run.sh
#ls -l /etc
#rtl_test
# ./run.sh
