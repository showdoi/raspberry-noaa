#!/bin/bash


## import common lib
. "$HOME/.noaa.conf"
. "$HOME/.tweepy.conf"
. "$NOAA_HOME/common.sh"


## pass start timestamp and sun elevation
PASS_START=$(expr "$5" + 90)
SUN_ELEV=$(python3 "$NOAA_HOME"/sun.py "$PASS_START")

if pgrep "rtl_fm" > /dev/null
then
	log "There is an existing rtl_fm instance running, I quit" "ERROR"
	exit 1
fi

# $1 = Satellite Name
# $2 = Frequency
# $3 = FileName base
# $4 = TLE File
# $5 = EPOC start time
# $6 = Time to capture
# $7 = Satellite max elevation

log "Starting rtl_fm record" "INFO"
timeout "${6}" /usr/local/bin/rtl_fm ${BIAS_TEE} -f "${2}"M -s 60k -g 50 -E wav -E deemp -F 9 - | /usr/bin/sox -t raw -e signed -c 1 -b 16 -r 60000 - "${RAMFS_AUDIO}/audio/${3}.wav" rate 11025

if [ ! -d "{NOAA_OUTPUT}/image/${FOLDER_DATE}" ]; then
	mkdir -m 775 -p "${NOAA_OUTPUT}/image/${FOLDER_DATE}"
fi

if [ "${SUN_ELEV}" -gt "${SUN_MIN_ELEV}" ]; then
	ENHANCEMENTS="ZA MCIR MCIR-precip MSA MSA-precip HVC-precip HVCT-precip HVC HVCT"
else
	ENHANCEMENTS="ZA MCIR MCIR-precip"
fi

log "Bulding pass map" "INFO"
/usr/local/bin/wxmap -T "${1}" -H "${4}" -p 0 -l 0 -o "${PASS_START}" "${NOAA_HOME}/map/${3}-map.png"
for i in $ENHANCEMENTS; do
	log "Decoding image" "INFO"
	/usr/local/bin/wxtoimg -o -m "${NOAA_HOME}/map/${3}-map.png" -e "$i" "${RAMFS_AUDIO}/audio/${3}.wav" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/${3}-$i.jpg"
	/usr/bin/convert -quality 90 -format jpg "${NOAA_OUTPUT}/image/${FOLDER_DATE}/${3}-$i.jpg" -undercolor black -fill yellow -pointsize 18 -annotate +20+20 "${1} $i ${START_DATE}" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/${3}-$i.jpg"
done

rm "${NOAA_HOME}/map/${3}-map.png"

if [ -n "$CONSUMER_KEY" ]; then
	log "Posting to Twitter" "INFO"
	if [ "${SUN_ELEV}" -gt "${SUN_MIN_ELEV}" ]; then
		python3 "${NOAA_HOME}/post.py" "$1 ${START_DATE}" "$7" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/$3-MCIR-precip.jpg" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/$3-MSA-precip.jpg" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/$3-HVC-precip.jpg" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/$3-HVCT-precip.jpg" 
	else
		python3 "${NOAA_HOME}/post.py" "$1 ${START_DATE}" "$7" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/$3-MCIR-precip.jpg" "${NOAA_OUTPUT}/image/${FOLDER_DATE}/$3-MCIR.jpg"
	fi
fi

if [ "$DELETE_AUDIO" = true ]; then
	log "Deleting audio files" "INFO"
    rm "${RAMFS_AUDIO}/audio/${3}.wav"
else
	log "Moving audio files out of the SD card" "INFO"
    mv "${RAMFS_AUDIO}/audio/${3}.wav" "${NOAA_OUTPUT}/audio/${3}.wav"
fi
