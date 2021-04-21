#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
height=512
width=1024
rm -f $PWD/../data/tmp/*

### layers
counter=1
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -r cubicspline -ts ${width} ${height} $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR_5400_2700.tif $PWD/../data/tmp/layer0.tif
ls $PWD/../data/gdps/*PRATE*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/thermal.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -cutline "$PWD/../data/maps/naturalearth/natural_earth_vector.gpkg" -csql "SELECT geom FROM ne_110m_ocean" -r cubicspline -ts ${width} ${height} /vsistdin/ $PWD/../data/tmp/layer1_$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done

### composite
count=$(ls $PWD/../data/tmp/layer1_*.tif | wc -l)
for (( counter = 1; counter <= ${count}; counter++ )); do
  convert $PWD/../data/tmp/layer0.tif $PWD/../data/tmp/layer1_$(printf "%06d" ${counter}).tif -gravity center -compose over -composite -level 50%,100% $PWD/../data/tmp/frame_$(printf "%06d" ${counter}).tif
done

### stream
ls -tr $PWD/../data/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../data/tmp/filelist.txt
ffmpeg -y -r 12 -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ocean_temp_$(date +%m_%d_%H%M%S).mp4
