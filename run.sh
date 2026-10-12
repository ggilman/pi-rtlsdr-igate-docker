#!/bin/sh

CONF_TEMPLATE=/sdr-igate.conf.template
# Written to /tmp so the container can run with a read-only root filesystem
CONF=/tmp/sdr-igate.conf

# Defaults
: "${IGSERVER:=noam.aprs2.net}"
: "${APRS_FREQUENCY:=144.39M}"
: "${DEVICE_INDEX:=0}"
: "${BEACON_DELAY:=1}"
: "${BEACON_EVERY:=10}"
: "${BEACON_SYMBOL:=R&}"
: "${GPSD_PORT:=2947}"
# Set COMMENT to an empty string to send beacons without a comment
COMMENT="${COMMENT-Docker APRS IGate}"

if [ -z "$MYCALL" ]; then
	echo "MYCALL environment variable must be set e.g. KK6GIP-7"
	exit 1
fi

if [ -z "$APRS_PASSWORD" ]; then
	echo "APRS_PASSWORD environment variable must be set e.g. 123456"
	exit 1
fi

echo "MYCALL: $MYCALL"
echo "APRS_FREQUENCY: $APRS_FREQUENCY"
echo "DEVICE_INDEX: $DEVICE_INDEX"
echo "IGSERVER: $IGSERVER"

SED_SCRIPT=$(mktemp)

# Add a {{NAME}} -> value substitution, escaping characters special to sed
subst () {
	printf 's|{{%s}}|%s|g\n' "$1" "$(printf '%s' "$2" | sed -e 's/[\\|&]/\\&/g')" >> "$SED_SCRIPT"
}

# Uncomment a directive in the template
enable () {
	printf 's|^#%s |%s |\n' "$1" "$1" >> "$SED_SCRIPT"
}

subst MYCALL "$MYCALL"
subst APRS_PASSWORD "$APRS_PASSWORD"
subst IGSERVER "$IGSERVER"

configure_beacon () {
	echo "BEACON_DELAY: $BEACON_DELAY"
	echo "BEACON_EVERY: $BEACON_EVERY"
	echo "BEACON_SYMBOL: $BEACON_SYMBOL"
	subst BEACON_DELAY "$BEACON_DELAY"
	subst BEACON_EVERY "$BEACON_EVERY"
	subst BEACON_SYMBOL "$BEACON_SYMBOL"
	if [ -n "$COMMENT" ]; then
		echo "COMMENT: $COMMENT"
		subst COMMENT "$COMMENT"
	else
		# Strip comment from beacon lines
		printf 's| comment="{{COMMENT}}"||\n' >> "$SED_SCRIPT"
	fi
}

# Users of this script can either provide LATITUDE & LONGITUDE, NMEA_GPS, or
# GPSD_HOST in order to send position beacons
if [ -n "$LATITUDE" ] && [ -n "$LONGITUDE" ]; then
	echo "PBEACON LATITUDE: $LATITUDE"
	echo "PBEACON LONGITUDE: $LONGITUDE"
	subst LATITUDE "$LATITUDE"
	subst LONGITUDE "$LONGITUDE"
	enable PBEACON
	configure_beacon
elif [ -n "$NMEA_GPS" ]; then
	echo "NMEA_GPS: $NMEA_GPS"
	subst NMEA_GPS "$NMEA_GPS"
	enable GPSNMEA
	enable TBEACON
	configure_beacon
elif [ -n "$GPSD_HOST" ]; then
	echo "GPSD_HOST: $GPSD_HOST"
	echo "GPSD_PORT: $GPSD_PORT"
	subst GPSD_HOST "$GPSD_HOST"
	subst GPSD_PORT "$GPSD_PORT"
	enable GPSD
	enable TBEACON
	configure_beacon
else
	echo "No LATITUDE/LONGITUDE, NMEA_GPS or GPSD_HOST set; position beacon disabled"
fi

if [ -n "$IGFILTER" ]; then
	echo "IGFILTER: $IGFILTER"
	subst IGFILTER "$IGFILTER"
	enable IGFILTER
fi

sed -f "$SED_SCRIPT" "$CONF_TEMPLATE" > "$CONF"
rm -f "$SED_SCRIPT"

# rtl_fm options: device, frequency and optional gain / PPM correction
set -- -d "$DEVICE_INDEX" -f "$APRS_FREQUENCY"
if [ -n "$RTL_GAIN" ]; then
	echo "RTL_GAIN: $RTL_GAIN"
	set -- "$@" -g "$RTL_GAIN"
fi
if [ -n "$RTL_PPM" ]; then
	echo "RTL_PPM: $RTL_PPM"
	set -- "$@" -p "$RTL_PPM"
fi

echo "Starting Direwolf"
# "-t 0" disables colors when logging
rtl_fm "$@" - | direwolf -c "$CONF" -t 0 -r 24000 -D 1 -
