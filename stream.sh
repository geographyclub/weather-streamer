#!/bin/bash
#get_metar.sh
#get_gdps.sh

##### utc -> local #####
#rm -f $PWD/../data/places_utc*
#awk -F '\t' '{print $176}' $PWD/../data/places.csv | sed -e 's/UTC//g' -e 's/:.*$//g' -e 's/±//g' -e 's/+//g' | while read a; do seq -f '%03g' -s ' ' $(echo "${a} - (${a}%3)" | bc) 3 $(echo "${a} - (${a}%3) + 21" | bc) | sed -e 's/-[0-9]\+ //g' -e 's/^/"/g' -e 's/$/"/g' >> $PWD/../data/places_utc_day1.txt; done
#awk -F '\t' '{print $176}' $PWD/../data/places.csv | sed -e 's/UTC//g' -e 's/:.*$//g' -e 's/±//g' -e 's/+//g' | while read a; do seq -f '%03g' -s ' ' $(echo "${a} - (${a}%3) + 24" | bc) 3 $(echo "${a} - (${a}%3) + 45" | bc) | sed -e 's/-[0-9]\+ //g' -e 's/^/"/g' -e 's/$/"/g' >> $PWD/../data/places_utc_day2.txt; done
#awk -F '\t' '{print $176}' $PWD/../data/places.csv | sed -e 's/UTC//g' -e 's/:.*$//g' -e 's/±//g' -e 's/+//g' | while read a; do seq -f '%03g' -s ' ' $(echo "${a} - (${a}%3) + 48" | bc) 3 $(echo "${a} - (${a}%3) + 69" | bc) | sed -e 's/-[0-9]\+ //g' -e 's/^/"/g' -e 's/$/"/g' >> $PWD/../data/places_utc_day3.txt; done
#awk -F '\t' 'BEGIN {OFS=","} {print $1 ',' $176}' $PWD/../data/places.csv | paste -d ',' - $PWD/../data/places_utc_day1.txt $PWD/../data/places_utc_day2.txt $PWD/../data/places_utc_day3.txt > $PWD/../data/places_utc.csv
#psql -d world -c "DROP TABLE IF EXISTS places_utc;"
#psql -d world -c "CREATE TABLE places_utc(ogc_fid int, utc text, day1 text, day2 text, day3 text);"
#psql -d world -c "COPY places_utc FROM '$PWD/../data/places_utc.csv' CSV;"

##### local names #####
#rm -f $PWD/../data/localname.sql
#echo $(psql -d world -c "\COPY (SELECT DISTINCT(iso_639_1) FROM places) TO STDOUT;") | tr ' ' '\n' | while read lang; do echo 'UPDATE places SET localname = name_'${lang} WHERE iso_639_1 = "'"${lang}"'"';' >> $PWD/../data/localname.sql; done
#UPDATE places a SET localname = b.alternatename FROM alternatenames b WHERE a.geonameid = b.geonameid AND a.iso_639_1 = b.isolanguage AND b.isolanguage NOT IN ('','iata','link','post','unlc','wkdt');

cat > $PWD/../data/grids/day1_tmax.vrt <<- EOM
<OGRVRTDataSource>
    <OGRVRTLayer name="my_table">
        <SrcDataSource>PG:"dbname=world"</SrcDataSource>
     	<SrcSQL>SELECT a.longitude, a.latitude, b.day1_tmax FROM places a, places_gdps_utc b AS my_table WHERE a.ogc_fid = b.ogc_fid</SrcSQL>
	    <GeometryType>wkbPoint</GeometryType>
            <LayerSRS>WGS84</LayerSRS>
	    <GeometryField encoding="PointFromColumns" x="longitude" y="latitude"/>
    </OGRVRTLayer>
</OGRVRTDataSource>
EOM

##### gridder #####
file=$PWD/../data/places_gdps_utc.csv
cat > ${file%.*}.vrt <<- EOM
<OGRVRTDataSource>
  <OGRVRTLayer name='places_gdps_utc'>
    <SrcDataSource>${file}</SrcDataSource>
    <LayerSRS>EPSG:4326</LayerSRS>
    <GeometryType>wkbPoint</GeometryType>
    <GeometryField encoding="PointFromColumns" x="lon" y="lat"/>
    <ExtentXMin>-180</ExtentXMin>
    <ExtentYMin>-90</ExtentYMin>
    <ExtentXMax>180</ExtentXMax>
    <ExtentYMax>90</ExtentYMax>
  </OGRVRTLayer>
</OGRVRTDataSource>
EOM
gdal_grid -of JPEG -co WRITE_BOTTOMUP=NO -zfield "temp" -a invdist -txe -180 180 -tye -90 90 -outsize ${width} $(( width/2 )) -ot Float64 -l $(basename "${file%.*}") ${file%.*}.vrt /home/steve/Downloads/tmp/temp.nc


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


ffmpeg -y -r 1/10 -i $PWD/../data/${stream}/%03d.svg -i "${audio}" -shortest -c:v libx264 -c:a aac -crf 23 -pix_fmt yuv420p -preset fast -threads 0 -movflags +faststart $PWD/../data/${stream}.mp4
#-e 's/<\/svg>/<text text-anchor="end" fill="#000000" stroke="none" fill-opacity="1" font-size="20" font-weight="870" xml:space="preserve" font-family="Montserrat" font-style="normal" x="99%" y="99%">Updated:'"${date_metar}"'<\/text>\n<\/svg>/g'
#ffmpeg -i <input> -vf "drawtext=text='%{localtime\:%T}'" -f flv <output>
#-vf drawtext="fontsize=60:fontfile=/home/steve/.fonts/fonts-master/ofl/montserrat/Montserrat-Regular.ttf:textfile=/home/steve/git/weatherchan/metar/metar_af.txt:y=h-line_h:x=-100*t"
#ffmpeg -y -r 1/10 -f lavfi -i color=c=black:s=1280x720 -r 1/10 -i $PWD/svgs/%03d.svg -i '/home/steve/Downloads/night vibes korean underground r&b + hiphop (14 songs).mp3' -filter_complex "[0:v][1:v]overlay=shortest=1,format=yuv420p[out]" -map "[out]" $PWD/test.mp4

##### git #####
#git add --all
#git commit -m 'utc fix'
#git push

