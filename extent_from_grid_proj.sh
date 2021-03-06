#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
place='Santiago'
coord=($(psql -d world -c "\COPY (SELECT round(ST_X(geom)), round(ST_Y(geom)) FROM places WHERE nameascii = '${place}') TO STDOUT"))
dir='/home/steve'
height=512
width=1024
rm -f ${dir}/tmp/*

### proj
proj='+proj=latlong +ellps=WGS84 +datum=WGS84 +pm='${coord[0]}''

### layers
gdalwarp -overwrite -dstalpha -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "${proj}" -te  -ts 0 ${height} ${dir}/maps/naturalearth/HYP_HR_SR_OB_DR/HYP_HR_SR_OB_DR.tif ${dir}/tmp/layer0.tif
display ${dir}/tmp/layer0.tif

counter=1
ls ${dir}/maps/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "${dir}/maps/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "${proj}" -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ ${dir}/tmp/layer1_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done

### labels
psql -d world -c "\COPY (SELECT a.nameascii, c.day1_tmin, c.day1_tmax, INITCAP(c.day1_wx), c.day2_tmin, c.day2_tmax, INITCAP(c.day2_wx), c.day3_tmin, c.day3_tmax, INITCAP(c.day3_wx) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.fid = c.fid AND a.nameascii = '${place}') TO STDOUT DELIMITER E'\t'" | while IFS=$'\t' read -a array; do
  convert -gravity east -background none -fill white -pointsize 16 -undercolor black -kerning 5 -font '/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-SemiBold.ttf' label:"${array[0]^^}\n${array[1]}/${array[2]}°C ${array[3]^^}\n${array[4]}/${array[5]}°C ${array[6]^^}\n${array[7]}/${array[8]}°C ${array[9]^^}" ${dir}/tmp/label.tif
done

### composite
count=$(ls ${dir}/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width}x${height} xc:white \( ${dir}/tmp/layer0_$(echo ${extent[*]} | tr ' ' '_').tif -scale 200% -level 30%,100% \) -gravity center -compose over -composite \( ${dir}/tmp/layer1_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif -scale 200% -level 30%,100% \) -gravity center -compose pegtoplight -composite \( ${dir}/tmp/label.tif -geometry +20+20 -level 30%,100% \) -gravity southeast -compose over -composite \( ${dir}/tmp/layer0_$(echo ${extent[*]} | tr ' ' '_').tif -scale 50% -level 50%,100% \) -gravity southwest -compose over -composite \( ${dir}/tmp/layer1_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif -scale 50% -level 50%,100% \) -gravity southwest -compose pegtoplight -composite \( +clone -modulate 200 -canny 0x0+10%+10% -negate \) -compose multiply -composite \( ${dir}/tmp/label.tif -geometry +20+20 \) -gravity southeast -compose over -composite ${dir}/tmp/frame_$(echo ${extent[*]} | tr ' ' '_')_$(printf "%06d" ${counter}).tif
done

### stream
video=$(echo ${dir}/out/extent_$(echo ${extent[*]} | tr ' ' '_')_$(date +%m_%d_%H%M%S).mp4)
ls -tr ${dir}/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > ${dir}/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i ${dir}/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart ${video}
ffplay -loop 0 ${video}
