#!/bin/bash

### params
place='Toronto'
continent='North America'
extent_x=40
extent_y=$((${extent_x}/2))
height=512
width=1024
samplemethod=cubicspline #nearest
colorfile=$PWD/../data/colors/white-black.txt
input0=$PWD/../data/maps/HYP_HR_SR_OB_DR.tif
proj=$(echo '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')
#proj=$(echo '+proj=ortho +lat_0=-10 +lon_0=-60')
field=TCDC #PRATE / PRMSL / TCDC / TMP
rate=10
time=30
color1=None
color2=Blue
fontcolor=Black
undercolor=None
#fontfile=/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf
fontfile=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-Bold.ttf
fontsize1='h/10'

### clip extent
if [ -z ${place} ]; then
  extent=(-180 -90 180 90)
  else extent=($(psql -d world -c "\COPY (SELECT ROUND(ST_X(ST_Translate(wkb_geometry,-${extent_x},0))), ROUND(ST_Y(ST_Translate(wkb_geometry,0,-${extent_y}))), ROUND(ST_X(ST_Translate(wkb_geometry,${extent_x},0))), ROUND(ST_Y(ST_Translate(wkb_geometry,0,${extent_y}))) FROM places WHERE nameascii = '${place}') TO STDOUT DELIMITER ' ';"))
fi

### make input(s)
if [ ! -f ${input0%.*}_$(echo ${extent[*]} | tr ' ' '_')_${width}_${height}_${samplemethod}.tif ]; then
  gdalwarp -overwrite -te ${extent[*]} -ts ${width} ${height} -r ${samplemethod} -t_srs "${proj}" ${input0} ${input0%.*}_$(echo ${extent[*]} | tr ' ' '_')_${width}_${height}_${samplemethod}.tif
fi
# make frames 
counter=1
rm -f $PWD/../data/tmp/*.tif
ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} ${colorfile} /vsistdout/ | gdalwarp -overwrite -f 'GTiff' -of 'GTiff' -te ${extent[*]} -ts ${width} ${height} -r ${samplemethod} --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE /vsistdin/ $PWD/../data/tmp/$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done
# imagemagick
ls $PWD/../data/tmp/*.tif | while read file; do
  convert -quiet -gravity Center -composite -compose Screen ${input0%.*}_$(echo ${extent[*]} | tr ' ' '_')_${width}_${height}_${samplemethod}.tif ${file} ${file}
done

### ticker
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (0) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' > $PWD/../data/tmp/ticker0.txt
psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C ' || a.wx_full || ' ' || '$(date +%a):' || CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END || '/' || CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END || '°C ' || INITCAP(c.day1_wx) || ' ' || '$(date --date="+1 day" +%a):' || c.day2_tmin || '/' || c.day2_tmax || '°C ' || INITCAP(c.day2_wx) || ' ' || '$(date --date="+2 day" +%a):' || c.day3_tmin || '/' || c.day3_tmax || '°C ' || INITCAP(c.day3_wx) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid AND a.nameascii = '${place}') TO STDOUT" > $PWD/../data/tmp/ticker.txt

### make video
# multiple inputs
#ffmpeg -y -r ${rate} -i ${input0%.*}_${width}_${height}_${samplemethod}.tif -i $PWD/../data/tmp/%06d.tif -filter_complex "[0:v][1:v] overlay=W-w:H-h" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4
# one input
#ffmpeg -y -r ${rate} -i $PWD/../data/tmp/%06d.tif -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4
# interpolate
#ffmpeg -y -r ${rate}/5 -i $PWD/../data/tmp/%06d.tif -vf "minterpolate='fps=120'" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4

ffmpeg -y -r ${rate} -loop 1 -i $PWD/../data/tmp/%06d.tif -vf "drawtext=fontsize=${fontsize1}: fontfile=${fontfile}: textfile=$PWD/../data/tmp/ticker.txt: x=W-((W+text_w)/(${time}/t)): y=(H/2)-(text_h/2)" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4


