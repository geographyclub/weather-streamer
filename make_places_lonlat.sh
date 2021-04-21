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

### hyp
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /home/steve/maps/naturalearth/HYP_HR_SR_OB_DR/HYP_HR_SR_OB_DR_5400_2700.tif /home/steve/tmp/hyp.tif

### 

### prate
counter=1
ls /home/steve/maps/gdps/*PRATE*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "/home/steve/maps/colors/precip.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ /home/steve/tmp/prate_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### prmsl
counter=1
ls /home/steve/maps/gdps/*PRMSL*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "/home/steve/maps/colors/gray.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ /home/steve/tmp/prmsl_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### tcdc
counter=1
ls /home/steve/maps/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "/home/steve/maps/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ /home/steve/tmp/tcdc_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done

### tmp
counter=1
ls /home/steve/maps/gdps/*TMP*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "/home/steve/maps/colors/temp.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -te ${extent[0]} ${extent[1]} ${extent[2]} ${extent[3]} -te_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ /home/steve/tmp/tmp_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 )) 
done


### labels
psql -d world -c "\COPY (SELECT a.nameascii, c.day1_tmin, c.day1_tmax, INITCAP(c.day1_wx), c.day2_tmin, c.day2_tmax, INITCAP(c.day2_wx), c.day3_tmin, c.day3_tmax, INITCAP(c.day3_wx) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.fid = c.fid AND a.nameascii = '${place}') TO STDOUT DELIMITER E'\t'" | while IFS=$'\t' read -a array; do
  convert -gravity east -background none -fill white -pointsize 16 -undercolor black -kerning 5 -font '/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-SemiBold.ttf' label:"${array[0]^^}\n${array[1]}/${array[2]}°C ${array[3]^^}\n${array[4]}/${array[5]}°C ${array[6]^^}\n${array[7]}/${array[8]}°C ${array[9]^^}" ${dir}/tmp/label.tif
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
