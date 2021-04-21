#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
place='Mexico City'
data=($(psql -d world -c "\COPY (SELECT fid, round(ST_X(geom)), round(ST_Y(geom)) FROM places WHERE nameascii = '${place}') TO STDOUT"))
extent=($(( ${data[1]} - 40 )) $(( ${data[2]} - 20 )) $(( ${data[1]} + 40 )) $(( ${data[2]} + 20 )))
width=1024
height=512
rm -f ${dir}/tmp/*

### layer0
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /home/steve/maps/naturalearth/HYP_HR_SR_OB_DR/HYP_HR_SR_OB_DR_5400_2700.tif /home/steve/tmp/layer0_${data[0]}.tif

counter=1
ls /home/steve/maps/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "/home/steve/maps/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ /home/steve/tmp/layer0_${data[0]}_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### ortho
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -s_srs 'EPSG:4326' -t_srs '+proj=ortho +lat_0='${data[2]}' +lon_0='${data[1]}' +ellps='sphere'' -ts 0 ${height} /home/steve/maps/naturalearth/HYP_HR_SR_OB_DR/HYP_HR_SR_OB_DR_5400_2700.tif /home/steve/tmp/layer1_${data[0]}.tif

counter=1
ls /home/steve/maps/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "/home/steve/maps/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs '+proj=ortho +lat_0='${array[2]}' +lon_0='${array[1]}' +ellps='sphere'' -ts 0 ${height} /vsistdin/ /home/steve/tmp/layer1_${data[0]}_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### composite
count=$(ls /home/steve/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width}x${height} xc:black \( /home/steve/tmp/layer1_${data[0]}_$(printf "%06d" ${counter}).tif \) gravity center -compose multiply -composite -level 50%,100% /home/steve/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
video=$(echo ${dir}/out/ortho_${lon_0}_${lat_0}_$(date +%m_%d_%H%M%S).mp4)
ls -tr ${dir}/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > ${dir}/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i ${dir}/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart ${video}
ffplay -loop 0 ${video}
