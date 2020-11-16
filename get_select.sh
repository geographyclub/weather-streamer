#!/bin/bash

### paramas
countrycode='au'
hoursbefore=72

### download (metar)
#file=$PWD/../data/metar/metar$(date +'%Y%m%d_%H%M%S')
file=$PWD/../data/metar/metar
curl -s "https://aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml&stationString=~${countrycode}&hoursBeforeNow=${hoursbefore}" | xmlstarlet sel -t -m "response/data/METAR" -v "station_id" -o ',' -v "observation_time" -o ',' -v "latitude" -o ',' -v "longitude" -o ',' -v "temp_c" -o ',' -v "dewpoint_c" -o ',' -v "wind_dir_degrees" -o ',' -v "wind_speed_kt" -o ',' -v "visibility_statute_mi" -o ',' -v "altim_in_hg" -o ',' -v "sea_level_pressure_mb" -o ',' -v "wx_string" -o ',' -v "(sky_condition/@sky_cover)[1]" -o ',' -v "precip_in" -o ',' -v "elevation_m" -n > ${file}.tmp
cat ${file}.tmp | awk '{print $12}' FS=',' | sed -E 's/([A-Z][A-Z])/\1 /g' | sed -e 's/\+/\+ /g' -e 's/\-/\- /g' -e 's/wx//g' | tr -s ' ' > ${file}_wx.tmp
echo "station_id,obs_time,lat,lon,temp,dewpoint,wind_dir,wind_sp,visibility,altim,pressure,wx,sky,precip,elevation,wx_split" > ${file}.csv
paste -d ',' ${file}.tmp ${file}_wx.tmp >> ${file}.csv

