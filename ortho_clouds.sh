#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
lon_0=60
lat_0=0
height=512
width=1024
rm -f $PWD/../data/tmp/*

### layers
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=ortho +lat_0='${lat_0}' +lon_0='${lon_0}'' -r cubicspline -ts ${height} ${height} $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR_5400_2700.tif $PWD/../data/tmp/layer0_${lon_0}_${lat_0}.tif

counter=1
ls $PWD/../data/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=ortho +lat_0='${lat_0}' +lon_0='${lon_0}'' -r cubicspline -ts ${height} ${height} /vsistdin/ $PWD/../data/tmp/layer1_${lon_0}_${lat_0}_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### composite
count=$(ls $PWD/../data/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width}x${height} xc:black \( $PWD/../data/tmp/layer0_${lon_0}_${lat_0}.tif -resize 75% -level 50%,100% \) -gravity center -compose over -composite \( $PWD/../data/tmp/layer1_${lon_0}_${lat_0}_$(printf "%06d" ${counter}).tif -resize 75% -level 50%,100% \) -gravity center -compose over -composite $PWD/../data/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
ls -tr $PWD/../data/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../data/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ortho_clouds_${lon_0}_${lat_0}_$(date +%m_%d_%H%M%S).mp4


