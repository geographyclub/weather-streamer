#!/bin/bash
#./get_metar.sh
#./get_gdps.sh

### params
audiofile=''
title=''
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
colorfile1="$PWD/../data/colors/white-black.txt"
colorfile2="$PWD/../data/colors/thermal.txt"
fontfile1=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-SemiBold.ttf
fontfile2=/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf
fontsize1=60
fontsize2=40
fontsize3=16
rm -f $PWD/../data/tmp/*

#################################################################

### get data
# ticker
#echo $(basename "${audiofile}") > $PWD/../data/tmp/ticker.txt
# largest cities
#psql -d world -c "\COPY (WITH myplaces AS (SELECT round((round(st_x(a.geom))/10))*10 x, round((round(st_y(a.geom))/10))*10 y, a.nameascii, round(b.temp), a.wx_full, CASE WHEN round(b.temp) < c.day1_tmin THEN round(b.temp) ELSE c.day1_tmin END, CASE WHEN round(b.temp) > c.day1_tmax THEN round(b.temp) ELSE c.day1_tmax END, INITCAP(c.day1_wx), c.day2_tmin, c.day2_tmax, INITCAP(c.day2_wx), c.day3_tmin, c.day3_tmax, INITCAP(c.day3_wx), round(st_x(a.geom)), round(st_y(a.geom)) FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid ORDER BY a.gn_pop DESC LIMIT 5) SELECT * FROM myplaces ORDER BY x) TO STDOUT DELIMITER E'\t'" > $PWD/../data/tmp/text.txt
# places
psql -d world -c "\COPY (SELECT round(st_x(a.geom)) x, round(st_y(a.geom)) y, round(st_x(st_shiftlongitude(a.geom))), a.nameascii, round(b.temp), a.wx_full FROM places a, metar b, places_gdps_utc c WHERE a.metar_id = b.station_id AND a.ogc_fid = c.ogc_fid AND a.nameascii IN ("${place}")) TO STDOUT DELIMITER E'\t'" > $PWD/../data/tmp/text.txt

#################################################################

### make globe
# scale
#gdalwarp -overwrite -dstalpha -t_srs "EPSG:4326" -ts 5400 2700 -r cubicspline $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR.tif $PWD/../data/maps/hyp/HYP_HR_SR_OB_DR_5400_2700.tif
# globe
#for ((x=-180; x<=180; x=x+10)); do
#  for ((y=-90; y<=90; y=y+10)); do
#    gdalwarp -overwrite -dstalpha -t_srs '+proj=ortho +lat_0='${y}' +lon_0='${x}'' -r cubicspline -ts ${height} ${height} "${basemap}" "${basemap%.*}"_${x}_${y}.tif
#  done
#done

# extent
gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -t_srs "${proj}" -r cubicspline -te $(( ${array[0]} - ${offset_x} )) $(( ${array[1]} - ${offset_y} )) $(( ${array[0]} + ${offset_x} )) $(( ${array[1]} + ${offset_y} )) -ts ${width} ${height} ${basemap} $PWD/../data/tmp/basemap_${array[0]}_${array[1]}.tif


counter=1
rm -f $PWD/../data/tmp/${field}_*.tif
rm -f $PWD/../data/tmp/basemap_*.tif
rm -f $PWD/../data/tmp/weathermap_*.tif
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  extent=($(( ${array[0]} - ${offset_x} )) $(( ${array[1]} - ${offset_y} )) $(( ${array[0]} + ${offset_x} )) $(( ${array[1]} + ${offset_y} )))
  gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "+proj=latlong +datum=WGS84 +pm=${array[2]}dE" -r cubicspline -ts ${width} ${height} ${basemap} $PWD/../data/tmp/basemap_${array[0]}_${array[1]}.tif
  ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
    gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -s_srs 'EPSG:4326' -t_srs "+proj=latlong +datum=WGS84 +pm=${array[2]}dE" -r cubicspline -ts ${width} ${height} /vsistdin/ $PWD/../data/tmp/${field}_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
    convert -quiet -level 50%,100% $PWD/../data/tmp/basemap_${array[0]}_${array[1]}.tif -write mpr:0 +delete $PWD/../data/tmp/${field}_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif -write mpr:1 +delete mpr:0 mpr:1 -compose over -composite -write mpr:2 +delete  mpr:2 -write mpr:3 +delete mpr:2 mpr:3 -compose multiply -composite $PWD/../data/tmp/weathermap_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
    (( counter = counter + 1 ))
  done
done


### make weather globe
counter=1
rm -f $PWD/../data/tmp/globe_*.tif
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  ls $PWD/../data/gdps/*${field}*.grib2 | while read file; do
    gdaldem color-relief -alpha -f 'GRIB' -of 'GTiff' --config GDAL_PAM_ENABLED NO ${file} "$PWD/../data/colors/white-black.txt" /vsistdout/ | gdalwarp -overwrite -dstalpha --config GDAL_PAM_ENABLED NO -co PROFILE=BASELINE -f 'GTiff' -of 'GTiff' -t_srs '+proj=ortho +lat_0='${array[1]}' +lon_0='${array[0]}'' -r cubicspline -ts ${height} ${height} /vsistdin/ /vsistdout/ | convert -quiet "${basemap%.*}"_${array[0]}_${array[1]}.tif - -gravity center -geometry +0+0 -compose over -composite -level 50%,100% $PWD/../data/tmp/globe_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
    (( counter = counter + 1 )) 
  done
done



### make labels
rm -f $PWD/../data/tmp/label_*.tif
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
# extruded title
#  convert -gravity Center -size ${width}x${height} xc:white -font "${fontfile1}" -pointsize ${fontsize1} -interline-spacing -10 -kerning 10 -fill "${color2}" -stroke "${color2}" -strokewidth 2 -annotate +5+10 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +4+8 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +3+6 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +2+4 "${title}" -stroke "${color2}" -strokewidth 2 -annotate +1+2 "${title}" -fill "${color1}" -stroke "${color2}" -strokewidth 2 -annotate +0+0 "${title}" $PWD/../data/tmp/label_title_${array[0]}_${array[1]}.tif
# caption
  convert -gravity center -geometry +0+0 -background white -fill black -font "${fontfile1}" -pointsize ${fontsize3} label:"${array[2]^^} ${array[3]}°C ${array[4]^^}" -bordercolor white -border 4x2 -bordercolor black -border 2x2 $PWD/../data/tmp/label_globe_west_$(printf "%06d" ${counter}).tif
# paragraph
#  printf "${array[2]^^}\n$(date +%a) ${array[5]}/${array[6]}°C ${array[7]^^}\n$(date --date='+1 day' +%a) ${array[8]}/${array[9]}°C ${array[10]^^}\n$(date --date='+2 day' +%a) ${array[11]}/${array[12]}°C ${array[13]^^}" | convert -gravity east -background "${color_bg1}" -fill "${color1}" -font "${fontfile1}" -pointsize ${fontsize2} -undercolor "${undercolor}" -interline-spacing -10 label:@- $PWD/../data/tmp/label_${array[0]}_${array[1]}.tif
# fit
#  convert -gravity east -background "${color_bg1}" -fill "${color1}" -font "${fontfile1}" -interline-spacing 0 -size ${width}x label:"${array[2]^^}" -trim +repage -resize ${width}x -write mpr:0 +delete \( -gravity east -background "${color_bg1}" -fill "${color1}" -font "${fontfile1}" -interline-spacing 0 -size ${width}x label:"${array[3]}°C" -trim +repage -resize ${width}x -write mpr:1 +delete \) -append mpr:0 mpr:1 $PWD/../data/tmp/label_${array[0]}_${array[1]}.tif
done

##########################################################

### composite
rm -f $PWD/../data/tmp/frame_*.tif
count=$(ls $PWD/../data/gdps/*${field}*.grib2 | wc -l)
cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
  for (( counter = 1; counter <= ${count}; counter++ )); do
    convert -size ${width}x${height} xc:"${color_bg2}" \( $PWD/../data/tmp/globe_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif -resize 75% \) -gravity center -geometry +0+0 -composite $PWD/../data/tmp/label_${array[0]}_${array[1]}.tif -gravity center -geometry +0+$(( ${height} / 4 )) -composite $PWD/../data/tmp/frame_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif
  done
done

# mask
#convert /home/steve/git/data/tmp/globe_120_30_000015.tif -modulate 200 -canny 0x0+10%+10% -negate -write mpr:0 +delete /home/steve/git/data/tmp/globe_120_30_000015.tif mpr:0 -compose multiply -composite -write mpr:1 +delete -alpha extract /home/steve/git/data/tmp/globe_120_30_000015.tif -write mpr:3 +delete mpr:1 -alpha off -compose copyopacity mpr:3 -composite /home/steve/git/data/tmp/globe_120_30_000015_comic.tif
# -modulate 200 -canny 0x0+10%+10% -negate
# -colorspace gray -level 50%,100%
# -sketch 0x10+120
# -resize 400% -implode 4 -resize 25%
# -morphology Convolve Gaussian:0x3
#convert balloon.gif \( +clone -matte -transparent black -fill white  -colorize 100% \) -composite balloon_mask_non-black.gif
#-auto-level
#-morphology Thinning:-1 Skeleton
#-modulate 200 -canny 0x0+10%+10% -negate
#-sharpen 0x6 
#-morphology convolve Gaussian:0x3



### make stream
# filelist
ls -tr $PWD/../data/tmp/frame_*.tif | sed -e "s/^/file '/g" -e "s/$/'/g" > $PWD/../data/tmp/filelist.txt
time=$(( $(cat $PWD/../data/tmp/filelist.txt | wc -l) / ${rate} ))
# clip audio
#ffmpeg -y -ss 00:00:30 -t $(( $(cat $PWD/../data/tmp/filelist.txt | wc -l) / ${rate} )) -i "${audiofile}" "${audiofile%.*}_clip.mp3"
# make video
#ffmpeg -y -r ${rate} -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -i "${audiofile%.*}_clip.mp3" -filter_complex "drawtext=fontsize=${fontsize2}: fontcolor='white': fontfile='${fontfile1}': text='$(cat $PWD/../data/tmp/ticker.txt)': x=W-((W+text_w)/(${time}/t)): y=(h-text_h)/1.1 [v]" -map "[v]" -map 1:a -t ${time} -shortest -c:v libx264 -c:a aac -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M%S).mp4
ffmpeg -y -r ${rate} -f concat -safe 0 -i $PWD/../data/tmp/filelist.txt -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../${field}_$(date +%m_%d_%H%M%S).mp4

########################################

### your asciiweather
#rm -f $PWD/../data/tmp/ascii_*
#count=$(ls $PWD/../data/gdps/*${field}*.grib2 | wc -l)
#cat $PWD/../data/tmp/text.txt | while IFS=$'\t' read -a array; do
#  for (( counter = 1; counter <= ${count}; counter++ )); do
#    convert $PWD/../data/tmp/globe_${array[0]}_${array[1]}_$(printf "%06d" ${counter}).tif jpg:- | jp2a --height=50 --output=$PWD/../data/tmp/ascii_globe_${array[0]}_${array[1]}_${counter}.txt -
#    (( counter = counter + 1 ))
#  done
#done
#cat $PWD/../data/tmp/ascii_globe_*.txt > $PWD/../data/tmp/ascii_globe.txt
#rate=5
#time=$(( $(ls $PWD/../data/tmp/ascii_globe_*.txt | wc -l) / ${rate} ))
#ffmpeg -y -f lavfi -i color=size=${width}x${height}:rate=5:color=black -t ${time} -filter_complex "drawtext=fontsize=$(( ${height} / 50 )): fontcolor='white': fontfile='${fontfile2}': textfile='$PWD/../data/tmp/ascii_globe.txt': x=((w-text_w)/2): y=(-50*line_h*t*${rate}): shadowcolor=blue: shadowx=10: shadowy=10" -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ascii_$(date +%m_%d_%H%M%S).mp4

##########################################

### misc ffmpeg
#minterpolate='fps=120'
#drawtext=fontsize=${fontsize1}: fontfile=${fontfile1}: textfile=$PWD/../data/tmp/text.txt: x=W-((W+text_w)/(${time}/t)): y=(H/2)-(text_h/2)
#drawtext=text='%{localtime\:%T}'"
#-i <(for i in {1..4}; do printf "file '%s'\n" input.mp4; done)
#drawbox=t=5:c=black
#enable=lt(mod(t\,3)\,1)
#[1:a] showwaves=s=${width}x${height}: colors=gray|black: mode=line: scale=log [v]; [v][0:v] overlay=W-w: H-h [v]
#[1:a] avectorscope=s=${width}x${height}: draw=dot: scale=log: zoom=2 [v]
#[1:a] aphasemeter=s=${width}x${height}: mpc=cyan [a][v] # -map "[a]"
#[1:a] showspectrum=s=${width}x${height}: color=nebulae: mode=combined: slide=scroll: saturation=0: scale=log [v]
#[1:a] showcqt=s=${width}x${height} [v]

### misc
#gdpstime_round=$(echo "$(date +%H) - ($(date +%H)%3)" | bc | awk '{ printf("%03d", $1) }')
#gdpstime=$(echo ${file} | sed -e 's/^.*_P//g' -e 's/\.grib2//g')
#date_metar=$(date -r $PWD/../data/metar/metar.csv)
#cutycapt --url=file://$PWD/$1.html --out=$PWD/$1.jpg

### make color
#gmt makecpt -N -Fr -C${color} -T0/100 |  awk '{ print $1, $2 }' | sed -e 's/ /% /g' -e 's/\// /g' > $PWD/../data/colors/${color}.txt
#gmt makecpt -Cwhite,blue -T3/10 > cold.cpt
#convert -size 10x1024 'gradient:rgba(255,255,255,0.0)-rgba(255,0,0,1)' $PWD/../data/colors/none-red.png
#convert -size 10x1024 xc:white -sparse-color Barycentric '0,0 rgba(255,255,255,0.0) 0,%h rgba(255,0,0,1)' -function polynomial 4,-4,1 $PWD/../data/colors/none-red-none.png
#convert -size 10x100 xc:black xc:purple xc:yellow -append -colorspace RGB -blur 0x20 -colorspace sRGB $PWD/../data/colors/black-purple-yellow.png
# svg to txt
#cat /home/steve/git/data/colors/cpt-city/cmocean/thermal.svg | grep '<stop offset' | sed -e 's/^.*<stop offset="//g' -e 's/" stop-color="rgb(/ /g' -e 's/).*$//g' -e 's/,//g' > /home/steve/git/data/colors/thermal.txt

