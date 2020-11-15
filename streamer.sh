#!/bin/bash
#get_metar.sh
#get_gdps.sh

### color (cpt)
#color=panoply
#gmt makecpt -N -Fr -C${color} -T0/100 |  awk '{ print $1, $2 }' | sed -e 's/ /% /g' -e 's/\// /g' > $PWD/../data/colors/${color}.txt
#gmt makecpt -Cwhite,blue -T3/10 > cold.cpt

### color (imagemagick)
#convert -size 10x1024 'gradient:rgba(255,255,255,0.0)-rgba(255,0,0,1)' $PWD/../data/colors/none-red.png
#convert -size 10x1024 xc:white -sparse-color Barycentric '0,0 rgba(255,255,255,0.0) 0,%h rgba(255,0,0,1)' -function polynomial 4,-4,1 $PWD/../data/colors/none-red-none.png
#convert -size 10x100 xc:black xc:purple xc:yellow -append -colorspace RGB -blur 0x20 -colorspace sRGB $PWD/../data/colors/black-purple-yellow.png
convert /home/steve/git/data/colors/cpt-city/dca/alarm.p1.0.2.svg -fuzz 20% -trim -rotate -90 -resize 10x1024! -depth 16 -colorspace rgb /home/steve/Downloads/alarm.p1.0.2.png

### qgis slideshow
files=$PWD/../data/qgis/places/%06d.png
rate=2
ffmpeg -y -stream_loop 1 -r ${rate} -i ${files} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../$(basename $(dirname ${files%.*}))_$(date +%m_%d_%H%M).mp4

# scroller
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C' FROM places a, metar b WHERE a.scalerank IN (0) AND a.metar_id = b.station_id) TO STDOUT;" | convert -gravity Center -size ${width}x -background ${color1} -fill ${fontcolor} -font "${fontfile}" -pointsize 40 caption:@- $PWD/../data/tmp/scroller1.png
#ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -i $PWD/../data/tmp/scroller.png -filter_complex "[0:v][1:v] overlay=W-w:H-((H+h)/(${time}/t)) [v]; [v] drawbox=x=0:y=0:w=iw:h=60:color=${color2}:t=max [v]; [v] drawbox=x=0:y=(ih-60):w=iw:h=60:color=${color2}:t=max [v]; [v] drawtext=fontsize=40: fontcolor=${fontcolor}: fontfile=${fontfile}: text='GCLUB WORLD WEATHER': x=(w-text_w)/2: y=15 [v]; [v] drawtext=fontsize=40: fontcolor=${fontcolor}: fontfile=${fontfile}: text='%{localtime\:%a %D %H%M %Z}': x=(w-text_w)/2: y=h-(line_h)-5 [v]" -map "[v]" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../scroller_$(date +%m_%d_%H%M).mp4


############## TODO ##############

# captions

# subset data 

### make gif
#convert -delay 50 $PWD/../data/qgis/places/*.png $PWD/../places_$(date +%m_%d_%H%M).gif
#convert -colorspace "Gray" -delay 2 $PWD/../data/weather/places/*.png -coalesce -layers OptimizePlus -layers RemoveZero miff:- | convert -duplicate 1,-1-0 -loop 0 - -coalesce -layers OptimizePlus -layers RemoveZero $PWD/../data/weather/test.gif

### imagemagick
height=512
width=1024
geom=1
blend=Screen
# crop
#convert -gravity Center -geometry $((width/geom))x$((height/geom))^ -crop $((width/geom))x$((height/geom))+0+0 -composite -compose ${blend} $1 /home/steve/Downloads/tmp/overlay.png /home/steve/Downloads/$(basename "${1%.*}")_$(basename "${2%.*}").png
convert -gravity Center -size ${width}x${height} -composite -compose ${blend}  /home/steve/Downloads/tmp/overlay.png /home/steve/Downloads/$(basename "${1%.*}")_$(basename "${2%.*}").png

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

### misc
#gdpstime_round=$(echo "$(date +%H) - ($(date +%H)%3)" | bc | awk '{ printf("%03d", $1) }')
#gdpstime=$(echo ${file} | sed -e 's/^.*_P//g' -e 's/\.grib2//g')
#convert -size 10x1024 gradient:navy-snow $PWD/../data/colors/ice-sea.png
#date_metar=$(date -r $PWD/../data/metar/metar.csv)

# justify text
cat ${file} | while read line; do 
  id=($(echo ${line} | awk -F "," '{print $1}'))
  words=($(echo ${line} | awk -F "," '{print $7}' | tr '-' ' '))
  lon=($(echo ${line} | awk -F "," '{print $23}'))
  lat=($(echo ${line} | awk -F "," '{print $22}'))
  for ((a=0; a<${#words[@]}; a=a+1)); do
    convert -background White -fill Black -font '/home/steve/.fonts/Google Webfonts/VT323-Regular.ttf' -size 1000x -interline-spacing 0 label:${words[a]^^} -trim +repage -resize 1000x -bordercolor White -border 10 /home/steve/Downloads/tmp/word${a}.ppm
  done
  convert -append $(ls -v /home/steve/Downloads/tmp/word*.ppm) /home/steve/Downloads/tmp/id_${id}.ppm
  potrace --progress -b svg --alphamax 1.0 --color \#000000 --opttolerance 0.2 --turdsize 0 --turnpolicy min --unit 10 --output ${dir}/id_${id}.svg /home/steve/Downloads/tmp/id_${id}.ppm
done
convert -gravity Center -append $(ls -v $PWD/../data/tmp/*.ppm) $PWD/../data/tmp/scroller.png

#-e 's/<\/svg>/<text text-anchor="end" fill="#000000" stroke="none" fill-opacity="1" font-size="20" font-weight="870" xml:space="preserve" font-family="Montserrat" font-style="normal" x="99%" y="99%">Updated:'"${date_metar}"'<\/text>\n<\/svg>/g'

# time
#ffmpeg -i <input> -vf "drawtext=text='%{localtime\:%T}'"

# no-file bash
#-i <(for i in {1..4}; do printf "file '%s'\n" input.mp4; done)

# border
#drawbox=t=5:c=black

# timed
#enable=lt(mod(t\,3)\,1)


