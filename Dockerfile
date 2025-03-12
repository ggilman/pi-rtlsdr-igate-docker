# Stage 1: Build Dependencies
FROM alpine:latest AS builder

# Install build dependencies
RUN apk update && apk add --no-cache bash git gcc g++ make cmake alsa-lib-dev linux-headers alsa-lib musl-utils libusb-dev

# Blacklist rtl modules
RUN echo "blacklist rtl2832\n\
blacklist r820t\n\
blacklist rtl2830\n\
blacklist dvb_usb_rtl28xxu" > /etc/modprobe.d/rtlsdr-blacklist.conf

WORKDIR /build
RUN git clone https://gitea.osmocom.org/argilo/rtl-sdr.git && \
    cd rtl-sdr && mkdir build && cd build && cmake ../ && make && make install

WORKDIR /build
RUN git clone https://www.github.com/wb2osz/direwolf && \
    cd direwolf && mkdir build && cd build && cmake .. && make -j4 && make install

# Create the /usr/local/etc directory
RUN mkdir -p /usr/local/etc/

# Copy the direwolf.conf file from the build directory
RUN cp /build/direwolf/build/direwolf.conf /usr/local/etc/direwolf.conf

# Cleanup build artifacts
RUN rm -rf /build/rtl-sdr /build/direwolf \
    && apk del bash git gcc g++ make cmake alsa-lib-dev linux-headers musl-utils libusb-dev

# Stage 2: Final Image
FROM alpine:latest

# Create default settings
ENV IGSERVER=noam.aprs2.net
ENV BEACON_DELAY=1
ENV BEACON_EVERY=10
ENV BEACON_SYMBOL=R\&
ENV COMMENT="Docker APRS IGate"
ENV LATITUDE=0.0
ENV LONGITUDE=0.0
ENV APRS_FREQUENCY=144.39M
ENV DEVICE_INDEX=0

WORKDIR /
COPY --from=builder /usr/local/bin/rtl_fm /usr/local/bin/rtl_fm
COPY --from=builder /usr/local/bin/direwolf /usr/local/bin/direwolf
COPY --from=builder /usr/local/etc/direwolf.conf /usr/local/etc/direwolf.conf
COPY sdr-igate.conf.template /
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Install runtime dependencies
RUN apk update && apk add --no-cache alsa-lib libusb

# Copy librtlsdr.so.2
COPY --from=builder /usr/local/lib/librtlsdr.so.2 /usr/local/lib/librtlsdr.so.2

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD ["/bin/sh", "-c", "ps aux | grep direwolf"]

CMD ["./run.sh"]
