ARG BASE_OS_TAG=3.21

# Stage 1: Build Dependencies
FROM alpine:${BASE_OS_TAG} AS builder

ARG APP_VERSION

# Install build dependencies
RUN apk update && apk add --no-cache --virtual .build-deps bash git gcc g++ make cmake alsa-lib-dev linux-headers alsa-lib musl-utils libusb-dev

# Blacklist rtl modules
RUN printf "blacklist rtl2832\nblacklist r820t\nblacklist rtl2830\nblacklist dvb_usb_rtl28xxu\n" > /etc/modprobe.d/rtlsdr-blacklist.conf

WORKDIR /build
RUN git clone --depth 1 https://gitea.osmocom.org/argilo/rtl-sdr.git && \
    cd rtl-sdr && mkdir build && cd build && cmake -Wno-dev ../ && make && make install

WORKDIR /build
RUN git clone --depth 1 --branch ${APP_VERSION} https://github.com/wb2osz/direwolf.git && \
    cd direwolf && mkdir build && cd build && cmake .. && make -j4 && make install

# Create the /usr/local/etc directory
RUN mkdir -p /usr/local/etc/

# Copy the direwolf.conf file from the build directory
RUN cp /build/direwolf/build/direwolf.conf /usr/local/etc/direwolf.conf

# Cleanup build artifacts and remove build dependencies
RUN rm -rf /build/rtl-sdr /build/direwolf && apk del .build-deps

# Stage 2: Final Image
FROM alpine:${BASE_OS_TAG}

LABEL maintainer="George Gilman"
LABEL description="Docker APRS IGate"

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
COPY --from=builder /usr/local/lib/librtlsdr.so.2 /usr/local/lib/librtlsdr.so.2
COPY sdr-igate.conf.template /sdr-igate.conf.template
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Install runtime dependencies
RUN apk update && apk add --no-cache alsa-lib libusb

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD pgrep -x direwolf > /dev/null

CMD ["/run.sh"]
