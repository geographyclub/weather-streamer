#!/bin/bash
#get_metar.sh
#get_gdps.sh

#!/bin/bash

### params
audiofile='/home/steve/Downloads/POCLANOS - Aseul - Dying Practice.mp3'
title='POCLANOS'
places="('Toronto')"
height=512
width=1024
basemap="$PWD/../data/maps/hyp/HYP_HR_SR_OB_DR_5400_2700.tif"
field=TCDC #PRATE / PRMSL / TCDC / TMP
rate=12
time=30
color1=white
color2=black
color_bg1=none
color_bg2=black
# vaporwave colors
color_vw1='rgb(255,113,206)'
color_vw2='rgb(1,205,254)'
undercolor='black'
fontfile1=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-SemiBold.ttf
fontfile2=/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf
fontsize1=60
fontsize2=40
fontsize3=16

### get data
# ticker
#echo $(basename "${audiofile}") > $PWD/../data/tmp/ticker.txt
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.metar_id = b.station_id AND a.scalerank IN (0,1)) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' > $PWD/../data/tmp/ticker.txt
# formatted text
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C ' || a.wx_full || ' ' || '$(date +%a):' || CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END || '/' || CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END || '°C ' || INITCAP(c.day1_wx) || ' ' || '$(date --date="+1 day" +%a):' || c.day2_tmin || '/' || c.day2_tmax || '°C ' || INITCAP(c.day2_wx) || ' ' || '$(date --date="+2 day" +%a):' || c.day3_tmin || '/' || c.day3_tmax || '°C ' || INITCAP(c.day3_wx) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid AND a.nameascii = '${place}') TO STDOUT" > $PWD/../data/tmp/text.txt
# largest cities
psql -d world -c "\COPY (WITH myplaces AS (SELECT round((round(st_x(a.wkb_geometry))/10))*10 x, round((round(st_y(a.wkb_geometry))/10))*10 y, a.nameascii, round(b.temp), a.wx_full, CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END, CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END, INITCAP(c.day1_wx), c.day2_tmin, c.day2_tmax, INITCAP(c.day2_wx), c.day3_tmin, c.day3_tmax, INITCAP(c.day3_wx), round(st_x(a.wkb_geometry)), round(st_y(a.wkb_geometry)) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid ORDER BY a.gn_pop DESC LIMIT 5) SELECT * FROM myplaces ORDER BY x) TO STDOUT DELIMITER E'\t'" > $PWD/../data/tmp/text.txt

### make globe
# scale
#gdalwarp -overwrite -dstalpha -t_srs "EPSG:4326" -ts 5400 2700 -r cubicspline $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR.tif $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR_5400_2700.tif
# globe
#for ((x=-180; x<=180; x=x+10)); do
#  for ((y=-90; y<=90; y=y+10)); do
#    gdalwarp -overwrite -dstalpha -t_srs '+proj=ortho +lat_0='${y}' +lon_0='${x}'' -r cubicspline -ts ${height} ${height} "${basemap}" "${basemap%.*}"_${x}_${y}.tif
#  done
#done

### make weather globe
counter=1
rm -f $PWD/../data/tmp/globe_*.tif
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
    gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -t_srs '+proj=ortho +lat_0='${array[1]}' +lon_0='${array[0]}'' -r cubicspline -ts ${height} ${height} /vsistdin/ /vsistdout/ | convert -quiet "${basemap%.*}"_${array[0]}_${array[1]}.tif - -gravity center -geometry +0+0 -compose over -composite -level 50%,100% $PWD/../data/tmp/globe_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
    (( counter = counter + 1 )) 
  done
done

### make extent
#counter=1
#rm -f $PWD/../data/tmp/bg_*.tif
#cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
#  ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
#    gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -r near -te $(( ${array[14]} - 20 )) $(( ${array[15]} - 10 )) $(( ${array[14]} + 20 )) $(( ${array[15]} + 10 )) -ts ${width} ${height} /vsistdin/ /vsistdout/ | convert -quiet -level 50%,100% -monochrome - $PWD/../data/tmp/bg_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
#    (( counter = counter + 1 ))
#  done
#done

### make labels
rm -f $PWD/../data/tmp/label_*.tif
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
# extruded title
  convert -gravity Center -size ${width}x${height} xc:white -font "${fontfile1}" -pointsize ${fontsize1} -interline-spacing -10 -kerning 10 -fill "${color2}" -stroke "${color2}" -strokewidth 2 -annotate +5+10 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +4+8 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +3+6 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +2+4 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +1+2 "${title}" -fill "${color1}" -stroke "${color2}" -strokewidth 2 -annotate +0+0 "${title}" $PWD/../data/tmp/label_title_${array[0]}_${array[1]}.tif
# caption
  convert -gravity center -geometry +0+0 -background white -fill black -font "${fontfile1}" -pointsize ${fontsize3} label:"${array[2]^^} ${array[3]}°C ${array[4]^^}" -bordercolor white -border 4x2 -bordercolor black -border 2x2 $PWD/../data/tmp/label_${array[0]}_${array[1]}.tif
# paragraph
#  printf "${array[2]^^}\n$(date +%a) ${array[5]}/${array[6]}°C ${array[7]^^}\n$(date --date='+1 day' +%a) ${array[8]}/${array[9]}°C ${array[10]^^}\n$(date --date='+2 day' +%a) ${array[11]}/${array[12]}°C ${array[13]^^}" | convert -gravity east -background "${color_bg1}" -fill "${color1}" -font "${fontfile1}" -pointsize ${fontsize2} -undercolor "${undercolor}" -interline-spacing -10 label:@- $PWD/../data/tmp/label_${array[0]}_${array[1]}.tif
# fit
#  convert -gravity east -background "${color_bg1}" -fill "${color1}" -font "${fontfile1}" -interline-spacing 0 -size ${width}x label:"${array[2]^^}" -trim +repage -resize ${width}x -write mpr:0 +delete \( -gravity east -background "${color_bg1}" -fill "${color1}" -font "${fontfile1}" -interline-spacing 0 -size ${width}x label:"${array[3]}°C" -trim +repage -resize ${width}x -write mpr:1 +delete \) -append mpr:0 mpr:1 $PWD/../data/tmp/label_${array[0]}_${array[1]}.tif
done

### composite
rm -f $PWD/../data/tmp/frame_*.tif
count=$(ls $PWD/../data/gdps/*${field}*.grib2 | wc -l)
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  for (( counter = 1; counter <= ${count}; counter++ )); do
    convert -size ${width}x${height} xc:"${color_bg2}" \( $PWD/../data/tmp/globe_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif -resize 75% \) -gravity center -geometry +0+0 -composite $PWD/../data/tmp/label_${array[0]}_${array[1]}.tif -gravity center -geometry +0+$(( ${height} / 4 )) -composite $PWD/../data/tmp/frame_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
  done
done

# -colorspace gray -level 50%,100%
# -sketch 0x10+120
# -resize 400%  -implode 4 -resize 25%
# -colorspace Gray -negate -edge 1 -negate

### asciiweather
#jp2a --html --html-fontsize=5 --width=100 --background=light --color --output=$PWD/$1.html $PWD/$1.jpg
#cutycapt --url=file://$PWD/$1.html --out=$PWD/$1.jpg

### make video
# filelist
ls -tr $PWD/../data/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../data/tmp/filelist.txt
time=$(( $(cat $PWD/../data/tmp/filelist.txt | wc -l) / ${rate} ))
# audio
#ffmpeg -y -ss 00:00:30 -t $(( $(cat $PWD/../data/tmp/filelist.txt | wc -l) / ${rate} )) -i "${audiofile}" "${audiofile%.*}_clip.mp3"
# video
#ffmpeg -y -r ${rate} -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -i "${audiofile%.*}_clip.mp3" -filter_complex "drawtext=fontsize=${fontsize2}: fontcolor='white': fontfile='${fontfile1}': text='$(cat $PWD/../data/tmp/ticker.txt)': x=W-((W+text_w)/(${time}/t)): y=(h-text_h)/1.1 [v]" -map "[v]" -map 1:a -t ${time} -shortest -c:v libx264 -c:a aac -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M%S).mp4
# video (no audio)
ffmpeg -y -r ${rate} -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M%S).mp4

### misc ffmpeg
# interpolate
#minterpolate='fps=120'
# ticker
#drawtext=fontsize=${fontsize1}: fontfile=${fontfile1}: textfile=$PWD/../data/tmp/text.txt: x=W-((W+text_w)/(${time}/t)): y=(H/2)-(text_h/2)
# audio visualizers
#[1:a] showwaves=s=${width}x${height}: colors=gray|black: mode=line: scale=log [v]; [v][0:v] overlay=W-w: H-h [v]
#[1:a] avectorscope=s=${width}x${height}: draw=dot: scale=log: zoom=2 [v]
#[1:a] aphasemeter=s=${width}x${height}: mpc=cyan [a][v] # -map "[a]"
#[1:a] showspectrum=s=${width}x${height}: color=nebulae: mode=combined: slide=scroll: saturation=0: scale=log [v]
#[1:a] showcqt=s=${width}x${height} [v]

### misc
#gdpstime_round=$(echo "$(date +%H) - ($(date +%H)%3)" | bc | awk '{ printf("%03d", $1) }')
#gdpstime=$(echo ${file} | sed -e 's/^.*_P//g' -e 's/\.grib2//g')
#convert -size 10x1024 gradient:navy-snow $PWD/../data/colors/ice-sea.png
#date_metar=$(date -r $PWD/../data/metar/metar.csv)
#-e 's/<\/svg>/<text text-anchor="end" fill="#000000" stroke="none" fill-opacity="1" font-size="20" font-weight="870" xml:space="preserve" font-family="Montserrat" font-style="normal" x="99%" y="99%">Updated:'"${date_metar}"'<\/text>\n<\/svg>/g'
# time
#ffmpeg -i <input> -vf "drawtext=text='%{localtime\:%T}'"
# no-file bash
#-i <(for i in {1..4}; do printf "file '%s'\n" input.mp4; done)
# border
#drawbox=t=5:c=black
# timed
#enable=lt(mod(t\,3)\,1)

### make color
#gmt makecpt -N -Fr -C${color} -T0/100 |  awk '{ print $1, $2 }' | sed -e 's/ /% /g' -e 's/\// /g' > $PWD/../data/colors/${color}.txt
#gmt makecpt -Cwhite,blue -T3/10 > cold.cpt
#convert -size 10x1024 'gradient:rgba(255,255,255,0.0)-rgba(255,0,0,1)' $PWD/../data/colors/none-red.png
#convert -size 10x1024 xc:white -sparse-color Barycentric '0,0 rgba(255,255,255,0.0) 0,%h rgba(255,0,0,1)' -function polynomial 4,-4,1 $PWD/../data/colors/none-red-none.png
#convert -size 10x100 xc:black xc:purple xc:yellow -append -colorspace RGB -blur 0x20 -colorspace sRGB $PWD/../data/colors/black-purple-yellow.png
#convert /home/steve/git/data/colors/cpt-city/dca/alarm.p1.0.2.svg -fuzz 20% -trim -rotate -90 -resize 10x1024! -depth 16 -colorspace rgb /home/steve/Downloads/alarm.p1.0.2.png


