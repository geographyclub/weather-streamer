#!/bin/bash

# video params
place='Toronto'
continent='North America'
videoname=$PWD/../TCDC_11_13_1352.mp4
height=512
width=1024
rate=100
time=40
# input params
color1=None
color2=Blue
fontcolor=Black
undercolor=None
#fontfile=/home/steve/.fonts/fonts-master/ofl/sourcecodepro/SourceCodePro-Regular.ttf
fontfile=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-Bold.ttf

### text to image
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (0) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' | convert -gravity West -background ${color1} -fill ${fontcolor} -undercolor ${undercolor} -font "${fontfile}" -size x$(( ${height} / 4 )) label:@- $PWD/../data/tmp/ticker0.png
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (1) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' | convert -gravity West -background ${color1} -fill ${fontcolor} -undercolor ${undercolor} -font "${fontfile}" -size x$(( ${height} / 6 )) label:@- $PWD/../data/tmp/ticker1.png
#psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (2) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' | convert -gravity West -background ${color1} -fill ${fontcolor} -undercolor ${undercolor} -font "${fontfile}" -size x$(( ${height} / 8 )) label:@- $PWD/../data/tmp/ticker2.png

### text
psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (0) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' > $PWD/../data/tmp/ticker0.txt
psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (1) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' > $PWD/../data/tmp/ticker1.txt
psql -d world -c "\COPY (SELECT a.nameascii || ' ' || round(b.temp) || '°C / ' FROM places a, metar b WHERE a.scalerank IN (2) AND a.continent IN ('${continent}') AND a.metar_id = b.station_id) TO STDOUT;" | tr -d '\n' | sed 's/ \/ $//' > $PWD/../data/tmp/ticker2.txt

### make video
# ticker (drawtext)
ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -filter_complex "drawtext=fontsize=h/3: text='(͡°͜ʖ͡°)': x=(W/2)-(text_w/2): y=(H/2)-(text_h/2): enable=lt(t\,1), drawtext=fontsize=h/3: fontfile=${fontfile}: textfile=$PWD/../data/tmp/ticker1.txt: x=W-((W+text_w)/(${time}/t)): y=(H/1)-(text_h), drawtext=fontsize=h/3: fontfile=${fontfile}: textfile=$PWD/../data/tmp/ticker0.txt: x=W-((W+text_w)/(${time}/t)): y=(H/2)-(text_h/2), drawtext=fontsize=h/3: fontfile=${fontfile}: textfile=$PWD/../data/tmp/ticker2.txt: x=W-((W+text_w)/(${time}/t)): y=(H/3)-(text_h)" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ticker_$(date +%m_%d_%H%M).mp4
# ticker (multiple drawtext)
#ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -vf "[0:v][1:v] overlay=W-w : H-((H+h)/(${time}/t)) [v]; [v] drawbox=x=0:y=0:w=iw:h=60:color=${color2}:t=max [v]; [v] drawbox=x=0:y=(ih-60):w=iw:h=60:color=${color2}:t=max [v]; [v] drawtext=fontsize=40: fontcolor=${fontcolor}: fontfile=${fontfile}: text='GCLUB WORLD WEATHER': x=(w-text_w)/2: y=15 [v]; [v] drawtext=fontsize=40: fontcolor=${fontcolor}: fontfile=${fontfile}: text='%{localtime\:%a %D %H%M %Z}': x=(w-text_w)/2: y=h-(line_h)-5 [v]" -map "[v]" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../scroller_$(date +%m_%d_%H%M).mp4

# ticker (single image)
#ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -i $PWD/../data/tmp/ticker0.png -i $PWD/../data/tmp/ticker1.png -filter_complex "[0:v][1:v] overlay=W-((W+w)/(${time}/t)):(H-h)/2 [v]; [v][2:v] overlay=W-((W+w)/(${time}/t)):(H-h)/3 [v]" -map "[v]" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ticker_$(date +%m_%d_%H%M).mp4
# ticker (multiple images)
#ffmpeg -y -f lavfi -i color=c=${color2}:s=${width}x${height} -i $PWD/../data/tmp/ticker0.png -i $PWD/../data/tmp/ticker1.png -i $PWD/../data/tmp/ticker2.png -filter_complex "[0:v][1:v] overlay=W-((W+w)/(${time}/t)):(H-h)/2 [v]; [v][2:v] overlay=W-((W+w)/(${time}/t)):(H-h)/3 [v]; [v][3:v] overlay=W-((W+w)/(${time}/t)):(H-h)/1.5 [v]; [v] minterpolate='fps=60' [v]" -map "[v]" -t ${time} -s ${width}x${height} -c:v libx264 -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../ticker_$(date +%m_%d_%H%M).mp4

