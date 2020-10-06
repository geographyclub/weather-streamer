#!/bin/bash
#get_metar.sh
#get_gdps.sh

### misc
#gdpstime_round=$(echo "$(date +%H) - ($(date +%H)%3)" | bc | awk '{ printf("%03d", $1) }')
#gdpstime=$(echo ${file} | sed -e 's/^.*_P//g' -e 's/\.grib2//g')
#convert -size 10x1024 gradient:navy-snow $PWD/../data/colors/ice-sea.png

### slideshow qgis
convert -delay 50 $PWD/../data/qgis/places/*.png $PWD/../places_$(date +%m_%d_%H%M).gif

### animate gdps
height=512
width=1024
samplemethod=cubicspline
colorfile=$PWD/../data/colors/white-black.txt
input0=$PWD/../data/maps/HYP_HR_SR_OB_DR_1500_751.tif
counter=1
field=TCDC
proj=$(echo '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')
#proj=$(echo '+proj=ortho +lat_0=-10 +lon_0=-60')
# make input(s)
if [ ! -f ${input0%.*}_${width}_${height}_${samplemethod}.tif ]; then
  gdalwarp -overwrite -ts ${width} ${height} -r ${samplemethod} -t_srs "${proj}" ${input0} ${input0%.*}_${width}_${height}_${samplemethod}.tif
  exit 0
fi
# make frames 
rm -f $PWD/../data/tmp/*.tif
ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
  gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} ${colorfile} /vsistdout/ | gdalwarp -overwrite -f 'GTiff' -of 'GTiff' -ts ${width} ${height} -r ${samplemethod} --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE /vsistdin/ $PWD/../data/tmp/$(printf "%06d" ${counter}).tif
  (( counter = counter + 1 ))
done
# make video
ffmpeg -y -r 10 -i ${input0%.*}_${width}_${height}_${samplemethod}.tif -i $PWD/../data/tmp/%06d.tif -filter_complex "[0:v][1:v] overlay=W-w:H-h" -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M).mp4

############## TODO ##############

# title

# captions

# ticker

# subset data 


### imagemagick
  convert $PWD/../data/weather/tcdc/$(printf "%06d" ${counter}).png -fill yellow -font '/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf' -pointsize 20 -gravity SouthEast -annotate 0 ${time} $PWD/../data/weather/tcdc/$(printf "%06d" ${counter})_color.png



### colorize
#convert -alpha off /home/steve/git/data/weather/tcdc/000001.jpg \( /home/steve/git/data/weather/colors/ice-sea.png -flip \) -channel RGB -interpolate Integer -clut /home/steve/git/data/weather/000001_colored.jpg
#convert -alpha off /home/steve/git/data/weather/tcdc/000001.jpg /home/steve/git/data/weather/colors/ice-sea.png -channel RGB -interpolate Integer -clut /home/steve/git/data/weather/000001_colored.jpg


##### caption0 #####
psql -d world -c "\COPY (SELECT a.ogc_fid, ROUND(ST_X(ST_ShiftLongitude(ST_MakePoint(a.longitude, a.latitude,4326)))), ROUND(ST_Y(ST_ShiftLongitude(ST_MakePoint(a.longitude, a.latitude,4326)))), a.nameascii, round(b.temp), b.wx_full, CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END, CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END, c.day1_wx, c.day2_tmin, c.day2_tmax, c.day2_wx, c.day3_tmin, c.day3_tmax, c.day3_wx FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid) TO STDOUT DELIMITER E'\t';" | while IFS=$'\t' read -a array; do echo ${array[0]}; done


##### stream0 #####
stream=stream0
audio='/home/steve/Downloads/night vibes korean underground r&b + hiphop (14 songs).mp3'
date_metar=$(date -r $PWD/../data/metar/metar.csv)
files=$PWD/../data/places/*.svg
rm -f $PWD/../data/${stream}/*.svg
cp ${files} $PWD/../data/${stream}/
ls ${files} | while read file; do echo $(cat ${file} | grep '@' | sed -e 's/^.*>@//g' -e 's/@<.*$//g') | while read ogc_fid; do IFS=$'\t'; data=($(psql -d world -c "\COPY (SELECT a.ogc_fid, a.nameascii, round(b.temp), b.wx_full, CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END, CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END, c.day1_wx, c.day2_tmin, c.day2_tmax, c.day2_wx, c.day3_tmin, c.day3_tmax, c.day3_wx FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid AND a.ogc_fid IN (${ogc_fid})) TO STDOUT DELIMITER E'\t';")); sed -i.bak -e 's/<svg.*$/<svg xmlns="http:\/\/www.w3.org\/2000\/svg" version="1.2" baseProfile="tiny" height="720px" width="1280px" viewBox="0 0 1280 720">\n<rect width="100%" height="100%" fill="#EDE7DC"\/>/g' -e 's/font-family="Montserrat"/font-family="Montserrat Black"/g' -e "s/@${data[0]}@/<tspan font-size=\"90\">${data[1]^^}<\/tspan><tspan font-size=\"90\" x=\"0\" dy=\"70\">${data[2]}°C ${data[3]^^}<\/tspan><tspan font-size=\"60\" x=\"0\" dy=\"55\">$(date +%^a):${data[4]}\/${data[5]}°C ${data[6]}<\/tspan><tspan font-size=\"60\" x=\"0\" dy=\"55\">$(date --date="+1 day" +%^a):${data[7]}\/${data[8]}°C ${data[9]}<\/tspan><tspan font-size=\"60\" x=\"0\" dy=\"55\">$(date --date="+2 day" +%^a):${data[10]}\/${data[11]}°C ${data[12]}<\/tspan>/g" $PWD/../data/${stream}/$(basename ${file}); done; done

#-e 's/<\/svg>/<text text-anchor="end" fill="#000000" stroke="none" fill-opacity="1" font-size="20" font-weight="870" xml:space="preserve" font-family="Montserrat" font-style="normal" x="99%" y="99%">Updated:'"${date_metar}"'<\/text>\n<\/svg>/g'
#ffmpeg -i <input> -vf "drawtext=text='%{localtime\:%T}'" -f flv <output>
#-vf drawtext="fontsize=60:fontfile=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-Regular.ttf:textfile=/home/steve/git/weatherchan/metar/metar_af.txt:y=h-line_h:x=-100*t"

ffmpeg -y -r 1/10 -f lavfi -i color=c=white:s=1024x512 -r 1/10 -i $PWD/../data/weather/places/%06d.svg -filter_complex "[0:v][1:v]overlay=shortest=1,format=yuv420p[out]" -map "[out]" $PWD/../data/weather/test.mp4

ffmpeg -y -r 1/10 -i $PWD/../data/weather/places/%06d.svg -s 1024x512 -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../data/weather/test.mp4

convert -colorspace "Gray" -delay 2 $PWD/../data/weather/places/*.png -coalesce -layers OptimizePlus -layers RemoveZero miff:- | convert -duplicate 1,-1-0 -loop 0 - -coalesce -layers OptimizePlus -layers RemoveZero $PWD/../data/weather/test.gif



