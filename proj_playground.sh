#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
place='Mexico City'
coord=($(psql -d world -c "\COPY (SELECT round(ST_X(geom)), round(ST_Y(geom)) FROM places WHERE nameascii = '${place}') TO STDOUT"))
dir='/home/steve'
height=512
width=1024
rm -f ${dir}/tmp/*

### proj
proj1='+proj=moll +lon_0='${coord[0]}''

### layers
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "${proj1}" -ts 0 ${height} ${dir}/maps/naturalearth/HYP_HR_SR_OB_DR/HYP_HR_SR_OB_DR_5400_2700.tif ${dir}/tmp/layer0.tif

counter=1
ls ${dir}/maps/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "${dir}/maps/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "${proj1}" -ts 0 ${height} /vsistdin/ ${dir}/tmp/layer1_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done

### composite
count=$(ls ${dir}/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width}x${height} xc:white \( ${dir}/tmp/layer0.tif -scale 300% \) -gravity center -compose over -composite \( ${dir}/tmp/layer1_$(printf "%06d" ${counter}).tif -scale 300% \) -gravity center -compose over -composite -level 50%,100% \( +clone -modulate 200 -canny 0x0+10%+10% -negate \) -compose multiply -composite ${dir}/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
video=$(echo ${dir}/out/proj_$(echo ${extent[*]} | tr ' ' '_')_$(date +%m_%d_%H%M%S).mp4)
ls -tr ${dir}/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > ${dir}/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i ${dir}/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart ${video}
ffplay -loop 0 ${video}
