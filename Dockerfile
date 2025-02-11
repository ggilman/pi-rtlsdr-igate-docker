FROM alpine:latest

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
ENV DEVICE_INDEX 0

RUN apk update  && \
        apk add bash \
        git gcc g++ make cmake \
        alsa-lib-dev linux-headers alsa-lib \
        musl-utils \
        libusb-dev

#RUN mkdir /etc/modprobe.d
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
&& make install
#RUN cd ~ && ls -l
#RUN ldconfig

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
RUN ln -s ./usr/local/bin/rtl_fm ./rtl_fm
RUN chmod +x ./rtl_fm

CMD ./run.sh
