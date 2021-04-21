#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
place='Toronto'
height=512
width=1024
rm -f $PWD/../data/tmp/*

### layers
primemeridian=$(psql -d world -c "\COPY (SELECT round(ST_X(ST_ShiftLongitude(geom))) FROM places WHERE nameascii = '${place}') TO STDOUT")
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "+proj=latlong +datum=WGS84 +pm=${primemeridian}dE" -r cubicspline -ts ${width} ${height} $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR_5400_2700.tif $PWD/../data/tmp/layer0_${primemeridian}.tif

counter=1
ls $PWD/../data/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "+proj=latlong +datum=WGS84 +pm=${primemeridian}dE" -r cubicspline -ts ${width} ${height} /vsistdin/ $PWD/../data/tmp/layer1_${primemeridian}_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done

### composite
count=$(ls $PWD/../data/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert $PWD/../data/tmp/layer0_${primemeridian}.tif $PWD/../data/tmp/layer1_${primemeridian}_$(printf "%06d" ${counter}).tif -gravity center -compose over -composite -level 50%,100% $PWD/../data/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
ls -tr $PWD/../data/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../data/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../shift_primemeridian_${primemeridian}_$(date +%m_%d_%H%M%S).mp4
