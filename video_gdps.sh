#!/bin/bash

### params
extent_x=40
extent_y=$((${extent_x}/2))
height=512
width=1024
proj=$(echo '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')
colorfile="$PWD/../data/colors/white-black.txt"
basemap="$PWD/../data/maps/HYP_HR_SR_OB_DR.tif"
field=TCDC #PRATE / PRMSL / TCDC / TMP
rate=10
time=30
color1=None
color2=Black
fontcolor=Black
undercolor='rgba(0,0,0,0.0)'
#fontfile=/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf
fontfile=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-Light.ttf
fontsize=35

### get data
# ticker
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C ' || a.wx_full || ' ' || '$(date +%a):' || CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END || '/' || CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END || '°C ' || INITCAP(c.day1_wx) || ' ' || '$(date --date="+1 day" +%a):' || c.day2_tmin || '/' || c.day2_tmax || '°C ' || INITCAP(c.day2_wx) || ' ' || '$(date --date="+2 day" +%a):' || c.day3_tmin || '/' || c.day3_tmax || '°C ' || INITCAP(c.day3_wx) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid AND a.nameascii = '${place}') TO STDOUT" > $PWD/../data/tmp/text.txt
# places
psql -d world -c "\COPY (WITH myplaces AS (SELECT ROUND(ST_X(a.wkb_geometry)) x, ROUND(ST_Y(a.wkb_geometry)) y, a.nameascii, round(b.temp), a.wx_full, CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END, CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END, INITCAP(c.day1_wx), c.day2_tmin, c.day2_tmax, INITCAP(c.day2_wx), c.day3_tmin, c.day3_tmax, INITCAP(c.day3_wx) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid ORDER BY a.gn_pop DESC LIMIT 5) SELECT * FROM myplaces ORDER BY x) TO STDOUT DELIMITER E'\t'" > $PWD/../data/tmp/text.txt

### make text
rm -f $PWD/../data/tmp/text_*.png
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  printf "${array[2]^^}\n${array[5]}/${array[6]}°C ${array[7]^^}\n${array[8]}/${array[9]}°C ${array[10]^^}\n${array[11]}/${array[12]}°C ${array[13]^^}" | convert -gravity Center -background ${color1} -fill ${fontcolor} -font "${fontfile}" -pointsize ${fontsize} -size $(( ${width} / 2 ))x${height} -undercolor ${undercolor} -interline-spacing -10 caption:@- $PWD/../data/tmp/text_${array[0]}_${array[1]}.png
done
#'$(date +%a)'
#'$(date --date="+1 day" +%a)'
#'$(date --date="+2 day" +%a)'

### make frames
# basemap
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  proj=$(echo '+proj=ortho +lat_0='${array[1]}' +lon_0='${array[0]}'')
  if [ ! -f ${basemap%.*}_${array[0]}_${array[1]}.tif ]; then
    gdalwarp -overwrite -t_srs "${proj}" -ts $(( ${width} / 2 )) ${height} -r cubicspline --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE "${basemap}" "${basemap%.*}"_${array[0]}_${array[1]}.tif
  fi
done
# weather
rm -f $PWD/../data/tmp/${field}_*.tif
counter=1
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
    proj=$(echo '+proj=ortho +lat_0='${array[1]}' +lon_0='${array[0]}'')
    gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} ${colorfile} /vsistdout/ | gdalwarp -overwrite -f 'GTiff' -of 'GTiff' -t_srs "${proj}" -ts $(( ${width} / 2 )) ${height} -r cubicspline --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE /vsistdin/ $PWD/../data/tmp/${field}_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
    (( counter = counter + 1 ))
  done
done
# imagemagick
rm -f $PWD/../data/tmp/frame_*.tif
counter=1
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  ls $PWD/../data/tmp/${field}_${array[0]}_${array[1]}_*.tif | while read file; do
#    convert -quiet -gravity Center -background ${color1} "${basemap%.*}"_${array[0]}_${array[1]}.tif ${file} -compose Screen -composite miff:- | convert - $PWD/../data/tmp/text_${array[0]}_${array[1]}.png -compose Overlay -composite $PWD/../data/tmp/frame_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
    convert -quiet -gravity Center -background ${color1} "${basemap%.*}"_${array[0]}_${array[1]}.tif ${file} -compose Screen -composite $PWD/../data/tmp/text_${array[0]}_${array[1]}.png -compose ATop -composite $PWD/../data/tmp/frame_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
    (( counter = counter + 1 ))
  done
done

### make video
# multiple inputs
#ffmpeg -y -r ${rate} -i ${input0%.*}_${width}_${height}.tif -i $PWD/../data/tmp/%06d.tif -filter_complex "[0:v][1:v] overlay=W-w:H-h" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4
# text overlay
#ffmpeg -y -r ${rate} -loop 1 -i $PWD/../data/tmp/%06d.tif -vf "drawtext=fontsize=${fontsize1}: fontfile=${fontfile}: textfile=$PWD/../data/tmp/text.txt: x=W-((W+text_w)/(${time}/t)): y=(H/2)-(text_h/2)" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4
# interpolate
#ffmpeg -y -r ${rate}/5 -i $PWD/../data/tmp/%06d.tif -vf "minterpolate='fps=120'" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4
# filelist
ls -tr $PWD/../data/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../data/tmp/filelist.txt
ffmpeg -y -r ${rate} -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -vf "pad=width=${width}:height=${height}:x=$(( ${width}/4 )):y=0:color=${color2}" -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M%S).mp4


