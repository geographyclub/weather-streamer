#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
place='Miami'
height=512
width=1024
rm -f $PWD/../data/tmp/*

### layers
center=($(psql -d world -c "\COPY (SELECT round(ST_X(geom)), round(ST_Y(geom)) FROM places WHERE nameascii = '${place}') TO STDOUT"))
extent=($(( ${center[0]} - 40 )) $(( ${center[1]} - 40 )) $(( ${center[0]} + 40 )) $(( ${center[1]} + 40 )))
gdalwarp -overwrite -dstalpha -te ${extent[*]} $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR_5400_2700.tif /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs' -r cubicspline -ts 0 ${height} /vsistdin/ $PWD/../data/tmp/layer0_$(echo ${extent[*]} | tr ' ' '_').tif

counter=1
ls $PWD/../data/gdps/*TMP*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' ${file} "$PWD/../data/colors/thermal.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha -te ${extent[*]} /vsistdin/ /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs' -r cubicspline -ts 0 ${height} /vsistdin/ $PWD/../data/tmp/layer1_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done

counter=1
ls $PWD/../data/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha -te ${extent[*]} /vsistdin/ /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs' -r cubicspline -ts 0 ${height} /vsistdin/ $PWD/../data/tmp/layer2_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done

### composite
count=$(ls $PWD/../data/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width}x${height} xc:black \( $PWD/../data/tmp/layer0_$(echo ${extent[*]} | tr ' ' '_').tif -modulate 200 -canny 0x0+10%+10% -negate \) -gravity center -compose over -composite $PWD/../data/tmp/layer1_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif -gravity center -compose multiply -composite $PWD/../data/tmp/layer2_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif -gravity center -compose over -composite -level 50%,100% $PWD/../data/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
ls -tr $PWD/../data/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../data/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../extent_clouds_temp_$(echo ${extent[*]} | tr ' ' '_')_$(date +%m_%d_%H%M%S).mp4
