Dockerfile and systemd script for running an APRS IGate (via [Direwolf](https://github.com/wb2osz/direwolf)) on a RaspberryPi with an attached RTL-SDR dongle.

I've tested this on a RaspberryPi 3, but it only takes < 20% CPU so I bet it runs on any RaspberryPi.

## Usage

Make sure you have Docker installed on the RaspberryPi. You probably want to run

    curl -sSL https://get.docker.com | sh

After that, you can easily run the version I have in Docker Hub (no need to even clone this repo). Replace `YOURCALLHERE` with your HAM callsign (e.g. mine is KK6GIP) and `YOURPASSWORDHERE` with your APRS password (generate one [here](http://apps.magicbug.co.uk/passcode/)) in the below command.

    docker pull ggilman/rtlsdr-igate-docker
    docker run --device /dev/bus/usb -e MYCALL=YOURCALLHERE -e APRS_PASSWORD=YOURPASSWORDHERE -it ggilman/rtlsdr-igate-docker

You now have a functioning IGate on your RaspberryPi! If you also want to send a beacon with the position of your IGate you can pass a latitude and longitude via environment variables.

    docker run --device /dev/bus/usb -e MYCALL=YOURCALLHERE -e APRS_PASSWORD=YOURPASSWORDHERE -e LATITUDE=30.1234 -e LONGITUDE=-90.1234 -e COMMENT="RaspberryPi + RTL-SDR + Direwolf" -it ggilman/rtlsdr-igate-docker

OR you can use a connected NMEA GPS to send position packets by setting the NMEA_GPS environment variable

    docker run --device /dev/bus/usb -e MYCALL=YOURCALLHERE -e APRS_PASSWORD=YOURPASSWORDHERE -e NMEA_GPS=/dev/ttyACM0 -e COMMENT="RaspberryPi + RTL-SDR + Direwolf" -it ggilman/rtlsdr-igate-docker

OR you can use a running gpsd instance by setting the GPSD_HOST (and optional GPSD_PORT) environment variables. You can use `dockerhost` to point back to the host machine. Note that you must use `--net=host` to access gpsd at `localhost`.

    docker run --device /dev/bus/usb -e MYCALL=YOURCALLHERE -e APRS_PASSWORD=YOURPASSWORDHERE -e GPSD_HOST=localhost --net=host -e COMMENT="RaspberryPi + RTL-SDR + Direwolf" -it ggilman/rtlsdr-igate-docker

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `MYCALL` | (required) | Callsign, e.g. `KK6GIP-10` |
| `APRS_PASSWORD` | (required) | APRS-IS passcode |
| `IGSERVER` | `noam.aprs2.net` | APRS-IS server |
| `IGFILTER` | | Optional APRS-IS server filter |
| `APRS_FREQUENCY` | `144.39M` | Receive frequency |
| `DEVICE_INDEX` | `0` | RTL-SDR device index (for multiple dongles) |
| `RTL_GAIN` | auto | Tuner gain in dB (`rtl_fm -g`) |
| `RTL_PPM` | | Frequency correction in PPM (`rtl_fm -p`) |
| `LATITUDE` / `LONGITUDE` | | Fixed position beacon |
| `NMEA_GPS` | | Serial NMEA GPS device for position beacon |
| `GPSD_HOST` / `GPSD_PORT` | / `2947` | gpsd instance for position beacon |
| `COMMENT` | `Docker APRS IGate` | Beacon comment; set empty to omit |
| `BEACON_DELAY` | `1` | Minutes before first beacon |
| `BEACON_EVERY` | `10` | Minutes between beacons |
| `BEACON_SYMBOL` | `R&` | APRS symbol |

The container can run with a read-only root filesystem (`--read-only --tmpfs /tmp`).

## systemd script

I've also included a systemd script which makes it easy to have the RaspberryPi start the IGate. To use it copy the systemd file to the appropriate location.

    sudo cp docker-igate.service.example /etc/systemd/system/docker-igate.service

Then edit the file to reflect your callsign, APRS password and (optionally) location.

    sudo nano /etc/systemd/system/docker-igate.service

Now start the service for the first time

    sudo systemctl daemon-reload
    sudo systemctl start docker-igate

Make sure it's running with `docker ps` and `systemctl status`

    docker ps
    sudo systemctl status docker-igate

Then optionally tell systemd to start the service at boot

    sudo systemctl enable docker-igate

You can see logs from the container by running

    docker logs -f docker-igate

## Push a new version to Docker Hub

This is mostly for my own reference. But you might want to run a variation of this command if you fork the Dockerfile and want to push it to Docker Hub (replace the docker hub repo with your repo).

    docker build . --tag "ggilman/rtlsdr-igate-docker:latest"
    docker push ggilman/rtlsdr-igate-docker:latest

## TODO

* Configure logging in a smarter way, probably in the systemd script (right now all logs from the Docker container go to `/var/log/syslog`)
