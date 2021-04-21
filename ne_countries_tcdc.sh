#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
dir='/home/steve'
height=512
width=1024
rm -f ${dir}/tmp/*

### layers
cat > ${dir}/tmp/layer0.svg <<- EOM
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg width="${width}" height="${height}" viewBox="-180 -90 360 180" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.2" baseProfile="tiny">
EOM
ogrinfo -sql 'SELECT AsSVG(geom,1) FROM ne_110m_admin_0_countries_lakes' ${dir}/maps/naturalearth/natural_earth_vector.gpkg | grep '(String) = ' | grep -v 'null' | sed -e 's/^.*= /<path d="/g' -e 's/$/" vector-effect="non-scaling-stroke" fill="none" stroke="#FFF" stroke-width="0.4px"\/>/g' >> ${dir}/tmp/layer0.svg
echo '</svg>' >> ${dir}/tmp/layer0.svg
convert -density 200 -background none ${dir}/tmp/layer0.svg ${dir}/tmp/tmp0.tif
gdal_translate -of 'GTiff' -a_ullr -180 90 180 -90 ${dir}/tmp/tmp0.tif /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ ${dir}/tmp/layer0.tif

counter=1
ls ${dir}/maps/gdps/*TCDC*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "${dir}/maps/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs 'EPSG:4326' -ts 0 ${height} /vsistdin/ ${dir}/tmp/layer1_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done

### composite
count=$(ls ${dir}/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert -size ${width}x${height} xc:black ${dir}/tmp/layer0.tif -gravity center -compose over -composite ${dir}/tmp/layer1_$(printf "%06d" ${counter}).tif -gravity center -compose over -composite ${dir}/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
video=$(echo ${dir}/out/ne_countries_tcdc_$(date +%m_%d_%H%M%S).mp4)
ls -tr ${dir}/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > ${dir}/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i ${dir}/tmp/filelist.txt -vf 'minterpolate='fps=120'' -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart ${video}
ffplay -loop 0 ${video}
