#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
lon_0=0
lat_0=-90
height=512
width=1024
dir='/home/steve'
rm -f ${dir}/tmp/*

### layers
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -s_srs 'EPSG:4326' -t_srs '+proj=ortho +lat_0='${lat_0}' +lon_0='${lon_0}' +ellps='sphere'' -ts 0 ${height} -r cubicspline ${dir}/maps/naturalearth/HYP_HR_SR_OB_DR/HYP_HR_SR_OB_DR_5400_2700.tif ${dir}/tmp/layer0_${lon_0}_${lat_0}.tif

counter=1
ls ${dir}/maps/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "${dir}/maps/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=ortho +lat_0='${lat_0}' +lon_0='${lon_0}' +ellps='sphere'' -ts 0 ${height} -r cubicspline /vsistdin/ ${dir}/tmp/layer1_${lon_0}_${lat_0}_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### composite
count=$(ls ${dir}/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width}x${height} xc:black \( ${dir}/tmp/layer0_${lon_0}_${lat_0}.tif -resize 75% \) -gravity center -compose over -composite \( ${dir}/tmp/layer1_${lon_0}_${lat_0}_$(printf "%06d" ${counter}).tif -resize 75% \) -gravity center -compose over -composite -level 50%,100% ${dir}/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
video=$(echo ${dir}/out/ortho_${lon_0}_${lat_0}_$(date +%m_%d_%H%M%S).mp4)
ls -tr ${dir}/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > ${dir}/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i ${dir}/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart ${video}
ffplay -loop 0 ${video}
