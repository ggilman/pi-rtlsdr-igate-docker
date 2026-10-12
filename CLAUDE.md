# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker image (`ggilman/rtlsdr-igate-docker`) that runs a receive-only APRS IGate: an RTL-SDR dongle feeds `rtl_fm`, which pipes audio into Direwolf, which forwards decoded packets to APRS-IS. There is no application code beyond `run.sh`; everything is configured through environment variables.

## Build and test

There is no test suite. Validate changes by building the image and running it:

```sh
docker build --build-arg BASE_OS_TAG=3.23 -t igate-test .

# Inspect the generated Direwolf config without an SDR attached (rtl_fm will exit with
# "No supported devices found", which is expected). Direwolf still parses the config and reports errors.
docker run --rm --read-only --tmpfs /tmp -e MYCALL=N0CALL -e APRS_PASSWORD=1 \
  -e LATITUDE=30.1 -e LONGITUDE=-85.6 igate-test \
  sh -c '/run.sh; grep -v "^#" /tmp/sdr-igate.conf | grep .'
```

Releases are built and pushed with the external script `~/scripts/build.sh` (not in this repo), run from the repo root. It reads `config.xml`:
- `version/major` + `version/minor` is the image tag; `-p` (multi-platform, tags `latest`) and `-n` (native) auto-increment the minor version and write it back to `config.xml`. `-d`/`-D` build `debug` tags without bumping. `-r X.Y` sets an explicit version.
- `upstream_version` is passed as `--build-arg APP_VERSION` (the Direwolf git tag); `BASE_OS_TAG` is auto-detected from the latest Alpine release.
- Optional `<build><foo>` elements become `--build-arg BUILD_FOO=...`.
- After building it verifies the image with `docker run IMAGE sh -c "command -v ./run.sh"`, so `run.sh` must stay at `/run.sh` with `WORKDIR /`.

## Architecture

- **Dockerfile**: two-stage Alpine build. The builder compiles rtl-sdr (argilo fork, pinned via `RTLSDR_COMMIT`) and Direwolf (`APP_VERSION`, linked against gpsd for `GPSD_HOST` support). The final stage copies only `rtl_fm`, `direwolf` and `librtlsdr.so.2`, plus runtime packages (`alsa-lib libusb gpsd tini su-exec`). `tini -g` is the entrypoint so SIGTERM reaches both ends of the `rtl_fm | direwolf` pipeline.
- **Privilege drop**: when started as root, `run.sh` first `chgrp igate` + `chmod g+rw` the passed-through `/dev/bus/usb` nodes and `$NMEA_GPS` (container-local copies, host is unaffected), then `exec su-exec igate "$0"` to re-run itself as the `igate` user (UID/GID 9001). Everything after that block runs unprivileged, so it must not need root.
- **run.sh**: the container's entrypoint logic, POSIX `sh` (BusyBox ash, not bash). Owns all env var defaults (the Dockerfile sets no `ENV`). It renders `sdr-igate.conf.template` into `/tmp/sdr-igate.conf` with one `sed` pass: `subst NAME value` replaces `{{NAME}}` (escaping `\ | &`), and `enable DIRECTIVE` uncomments a `#DIRECTIVE` line. Writing to `/tmp` lets the container run with a read-only root filesystem.
- **Position beacon modes** are mutually exclusive and checked in order: `LATITUDE`+`LONGITUDE` → `PBEACON`; `NMEA_GPS` → `GPSNMEA` + `TBEACON`; `GPSD_HOST` → `GPSD` + `TBEACON`; otherwise no beacon.
- `DEVICE_INDEX`, `RTL_GAIN`, `RTL_PPM` are `rtl_fm` options; Direwolf's own `-d` is a debug flag, not a device index.

When adding an env var, update together: `run.sh` (default + substitution), `sdr-igate.conf.template` (placeholder), and the env var table in `README.md`, plus the commented examples in `docker-compose.yml` and `docker-igate.service.example` where relevant. In compose's list-style `environment:`, values must not be quoted (quotes become part of the value).
