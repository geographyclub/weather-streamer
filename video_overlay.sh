#!/bin/bash

# video params
place='Toronto'
videoname=$PWD/../TCDC_11_13_1352.mp4
height=512
width=1024
rate=100
time=20
# input params
color1=None
color2=Blue
fontcolor=Black
undercolor=None
#fontfile=/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf
fontfile=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-Bold.ttf

### text to image
psql -d world -c "\COPY (SELECT CONCAT(UPPER(a.nameascii), ', ', UPPER(a.adm1name), ', ', a.iso_a2), CONCAT('Now: ', round(b.temp), '°C ', a.wx_full), CONCAT('$(date +%a): ', CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END, '/', CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END, '°C ', INITCAP(c.day1_wx)), CONCAT('$(date --date="+1 day" +%a): ', c.day2_tmin, '/', c.day2_tmax, '°C ', INITCAP(c.day2_wx)), CONCAT('$(date --date="+2 day" +%a): ', c.day3_tmin, '/', c.day3_tmax, '°C ', INITCAP(c.day3_wx)) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid AND a.nameascii = '${place}') TO STDOUT;" | tr '\t' '\n' | head -c -1 | convert -gravity Center -size ${width}x${height} -background ${color1} -fill ${fontcolor} -undercolor ${undercolor} -font "${fontfile}" -pointsize 40 -interline-spacing 0.8 caption:@- $PWD/../data/tmp/text.png

# make video
#ffmpeg -y -i ${videoname} -i $PWD/../data/tmp/text.png -filter_complex "[0:v][1:v] overlay [v]" -map "[v]" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../overlay_$(date +%m_%d_%H%M).mp4
ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -i $PWD/../data/tmp/text.png -filter_complex "[0:v][1:v] overlay [v]" -map "[v]" -s ${width}x${height} -t ${time} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../overlay_$(date +%m_%d_%H%M).mp4



