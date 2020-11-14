#!/bin/bash

### params
height=512
width=1024
samplemethod=cubicspline #nearest
colorfile=$PWD/../data/colors/white-black.txt
input0=$PWD/../data/maps/HYP_HR_SR_OB_DR_1500_751.tif
rate=10
time=20
field=TCDC #PRATE / PRMSL / TCDC / TMP
proj=$(echo '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')
#proj=$(echo '+proj=ortho +lat_0=-10 +lon_0=-60')

### make input(s)
if [ ! -f ${input0%.*}_${width}_${height}_${samplemethod}.tif ]; then
  gdalwarp -overwrite -ts ${width} ${height} -r ${samplemethod} -t_srs "${proj}" ${input0} ${input0%.*}_${width}_${height}_${samplemethod}.tif
  exit 0
fi
# make frames 
counter=1
rm -f $PWD/../data/tmp/*.tif
ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} ${colorfile} /vsistdout/ | gdalwarp -overwrite -f 'GTiff' -of 'GTiff' -ts ${width} ${height} -r ${samplemethod} --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE /vsistdin/ $PWD/../data/tmp/$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done
# imagemagick
ls $PWD/../data/tmp/*.tif | while read file; do
  convert -quiet -gravity Center -composite -compose Screen ${input0%.*}_${width}_${height}_${samplemethod}.tif ${file} ${file}
done

### make video
# multiple inputs
#ffmpeg -y -r ${rate} -i ${input0%.*}_${width}_${height}_${samplemethod}.tif -i $PWD/../data/tmp/%06d.tif -filter_complex "[0:v][1:v] overlay=W-w:H-h" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4
# one input
#ffmpeg -y -r ${rate} -i $PWD/../data/tmp/%06d.tif -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4
# interpolate
ffmpeg -y -r ${rate}/5 -i $PWD/../data/tmp/%06d.tif -vf "minterpolate='fps=120'" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4

