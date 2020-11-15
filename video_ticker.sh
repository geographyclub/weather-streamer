#!/bin/bash

# video params
place='Toronto'
continent='North America'
videoname=$PWD/../TCDC_11_13_1352.mp4
height=512
width=1024
rate=100
time=100
# input params
color1=None
color2=Blue
fontcolor=Black
undercolor=None
#fontfile=/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf
fontfile=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-Bold.ttf

### text to image
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (0) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | convert -gravity West -background ${color1} -fill ${fontcolor} -undercolor ${undercolor} -font "${fontfile}" -size x$(( ${height} / 4 )) label:@- $PWD/../data/tmp/ticker0.png
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (1) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | convert -gravity West -background ${color1} -fill ${fontcolor} -undercolor ${undercolor} -font "${fontfile}" -size x$(( ${height} / 6 )) label:@- $PWD/../data/tmp/ticker1.png
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (2) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | convert -gravity West -background ${color1} -fill ${fontcolor} -undercolor ${undercolor} -font "${fontfile}" -size x$(( ${height} / 8 )) label:@- $PWD/../data/tmp/ticker2.png

### text
psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (0) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' > $PWD/../data/tmp/ticker0.txt
psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (1) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' > $PWD/../data/tmp/ticker1.txt
psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (2) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' > $PWD/../data/tmp/ticker2.txt


# make video
# ticker (drawtext)
#ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -vf "drawtext=fontsize=30: fontfile=/home/steve/.fonts/fonts-master/ofl/overpassmono/OverpassMono-Regular.ttf: textfile=$PWD/../data/tmp/ticker.txt: x=${width}-(${rate}*t): y=h-(line_h)" -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ticker_$(date +%m_%d_%H%M).mp4
# ticker (single)
#ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -i $PWD/../data/tmp/ticker0.png -i $PWD/../data/tmp/ticker1.png -filter_complex "[0:v][1:v] overlay=W-((W+w)/(${time}/t)):(H-h)/2 [v]; [v][2:v] overlay=W-((W+w)/(${time}/t)):(H-h)/3 [v]" -map "[v]" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ticker_$(date +%m_%d_%H%M).mp4
# ticker (multiple)
ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -i $PWD/../data/tmp/ticker0.png -i $PWD/../data/tmp/ticker1.png -i $PWD/../data/tmp/ticker2.png -filter_complex "[0:v][1:v] overlay=W-((W+w)/(${time}/t)):(H-h)/2 [v]; [v][2:v] overlay=W-((W+w)/(${time}/t)):(H-h)/3 [v]; [v][3:v] overlay=W-((W+w)/(${time}/t)):(H-h)/1.5 [v]; [v] minterpolate='fps=60' [v]" -map "[v]" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ticker_$(date +%m_%d_%H%M).mp4


