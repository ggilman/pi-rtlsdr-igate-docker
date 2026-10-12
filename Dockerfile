ARG BASE_OS_TAG=3.21

# Stage 1: Build Dependencies
FROM alpine:${BASE_OS_TAG} AS builder

ARG APP_VERSION=1.8.1
# Pinned commit of the argilo rtl-sdr fork (for reproducible builds)
ARG RTLSDR_COMMIT=448a6551ab68ad143b5129b82b345f15c13f8825

# Install build dependencies
RUN apk add --no-cache git gcc g++ make cmake linux-headers alsa-lib-dev libusb-dev gpsd-dev

WORKDIR /build
RUN git clone https://gitea.osmocom.org/argilo/rtl-sdr.git && \
    git -C rtl-sdr checkout ${RTLSDR_COMMIT} && \
    cmake -S rtl-sdr -B rtl-sdr/build -Wno-dev -DCMAKE_BUILD_TYPE=Release && \
    make -C rtl-sdr/build -j"$(nproc)" && make -C rtl-sdr/build install

RUN git clone --depth 1 --branch ${APP_VERSION} https://github.com/wb2osz/direwolf.git && \
    cmake -S direwolf -B direwolf/build -DCMAKE_BUILD_TYPE=Release && \
    make -C direwolf/build -j"$(nproc)" && make -C direwolf/build install

# Strip debug symbols to shrink the final image
RUN strip /usr/local/bin/rtl_fm /usr/local/bin/direwolf "$(readlink -f /usr/local/lib/librtlsdr.so.2)"

# Stage 2: Final Image
FROM alpine:${BASE_OS_TAG}

LABEL maintainer="George Gilman"
LABEL description="Docker APRS IGate"

# Install runtime dependencies (before COPY so script edits don't invalidate this layer)
# gpsd provides libgps, needed for the GPSD_HOST option
RUN apk add --no-cache alsa-lib libusb gpsd tini

WORKDIR /

COPY --from=builder /usr/local/bin/rtl_fm /usr/local/bin/direwolf /usr/local/bin/
COPY --from=builder /usr/local/lib/librtlsdr.so.2 /usr/local/lib/
COPY sdr-igate.conf.template /sdr-igate.conf.template
COPY --chmod=755 run.sh /run.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD pgrep -x direwolf > /dev/null

# tini -g forwards SIGTERM to the whole process group (rtl_fm and direwolf)
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD ["/run.sh"]
