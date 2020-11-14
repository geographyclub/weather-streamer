#!/bin/bash

##### download #####
#file=$PWD/../data/metar/metar$(date +'%Y%m%d_%H%M%S')
file=$PWD/../data/metar/metar
curl -s "https://aviationweather.gov/adds/dataserver_current/current/metars.cache.xml.gz" | gzip -d | xmlstarlet sel -t -m "response/data/METAR" -v "station_id" -o ',' -v "observation_time" -o ',' -v "latitude" -o ',' -v "longitude" -o ',' -v "temp_c" -o ',' -v "dewpoint_c" -o ',' -v "wind_dir_degrees" -o ',' -v "wind_speed_kt" -o ',' -v "visibility_statute_mi" -o ',' -v "altim_in_hg" -o ',' -v "sea_level_pressure_mb" -o ',' -v "wx_string" -o ',' -v "(sky_condition/@sky_cover)[1]" -o ',' -v "precip_in" -o ',' -v "elevation_m" -n > ${file}.tmp
cat ${file}.tmp | awk '{print $12}' FS=',' | sed -E 's/([A-Z][A-Z])/\1 /g' | sed -e 's/\+/\+ /g' -e 's/\-/\- /g' -e 's/wx//g' | tr -s ' ' > ${file}_wx.tmp
echo "station_id,obs_time,lat,lon,temp,dewpoint,wind_dir,wind_sp,visibility,altim,pressure,wx,sky,precip,elevation,wx_split" > ${file}.csv
paste -d ',' ${file}.tmp ${file}_wx.tmp >> ${file}.csv

##### psql #####
mytable=metar
psql -d world -c "DROP TABLE IF EXISTS ${mytable};"
psql -d world -c "CREATE TABLE ${mytable}(station_id text, obs_time date, lat float8, lon float8, temp float8, dewpoint float8, wind_dir int, wind_sp int, visibility float8, altim float8, pressure float8, wx text, sky text, precip float8, elevation float8, wx_split text);"
psql -d world -c "COPY ${mytable} FROM '$PWD/../data/metar/metar.csv' DELIMITER ',' CSV HEADER;"
psql -d world -c "SELECT AddGeometryColumn('${mytable}','wkb_geometry2',4326,'POINT',2);"
psql -d world -c "UPDATE ${mytable} SET wkb_geometry2 = ST_SetSRID(ST_MakePoint(lon,lat),4326);"
psql -d world -c "CREATE INDEX ${mytable}_gid ON ${mytable} USING GIST (wkb_geometry2);"

##### metar codes #####
psql -d world -c "ALTER TABLE metar ADD COLUMN wx_full text, ADD COLUMN wx_full_1 text, ADD COLUMN wx_full_2 text, ADD COLUMN wx_full_3 text, ADD COLUMN wx_full_4 text, ADD COLUMN wx_full_5 text;"
psql -d world -c "UPDATE metar a SET wx_full_1 = b.wx_full FROM metar_wx_codes b WHERE SPLIT_PART(a.wx_split,' ',1) = b.wx_code AND b.type NOT IN ('Descriptor','Intensity');"
psql -d world -c "UPDATE metar a SET wx_full_2 = b.wx_full FROM metar_wx_codes b WHERE SPLIT_PART(a.wx_split,' ',2) = b.wx_code AND b.type NOT IN ('Descriptor','Intensity') AND SPLIT_PART(a.wx_split,' ',1) != SPLIT_PART(a.wx_split,' ',2);"
psql -d world -c "UPDATE metar a SET wx_full_3 = b.wx_full FROM metar_wx_codes b WHERE SPLIT_PART(a.wx_split,' ',3) = b.wx_code AND b.type NOT IN ('Descriptor','Intensity');"
psql -d world -c "UPDATE metar a SET wx_full_4 = b.wx_full FROM metar_wx_codes b WHERE SPLIT_PART(a.wx_split,' ',4) = b.wx_code AND b.type NOT IN ('Descriptor','Intensity');"
psql -d world -c "UPDATE metar a SET wx_full_5 = b.wx_full FROM metar_wx_codes b WHERE SPLIT_PART(a.wx_split,' ',5) = b.wx_code AND b.type NOT IN ('Descriptor','Intensity');"
psql -d world -c "UPDATE metar SET wx_full = (SELECT REGEXP_REPLACE(REPLACE(COALESCE(wx_full_1,',') || ',' || COALESCE(wx_full_2,',') || ',' || COALESCE(wx_full_3,',') || ',' || COALESCE(wx_full_4,',') || ',' || COALESCE(wx_full_5,','),',,',''),'^,',''));"
psql -d world -c "UPDATE metar SET wx_full = 'Clear' WHERE sky IN ('CAVOK','CLR','NCD','NSC','SKC') AND wx_full = '';"
psql -d world -c "UPDATE metar SET wx_full = 'Cloudy' WHERE sky IN ('BKN','OVC','OVX') AND wx_full = '';"
psql -d world -c "UPDATE metar SET wx_full = 'Partly Cloudy' WHERE sky IN ('FEW','SCT') AND wx_full = '';"
psql -d world -c "UPDATE metar SET wx_full = NULL WHERE wx_full = '';"

##### join codes #####
psql -d world -c "ALTER TABLE places ADD COLUMN IF NOT EXISTS metar_id text, ADD COLUMN IF NOT EXISTS metar_id2 text, ADD COLUMN IF NOT EXISTS wx_full text;"
psql -d world -c "UPDATE places a SET metar_id = (SELECT b.station_id FROM ${mytable} b ORDER BY a.wkb_geometry <-> b.wkb_geometry2 LIMIT 1);"
psql -d world -c "UPDATE places a SET metar_id2 = (SELECT b.station_id FROM ${mytable} b WHERE a.metar_id != b.station_id ORDER BY a.wkb_geometry <-> b.wkb_geometry2 LIMIT 1);"
psql -d world -c "UPDATE places a SET wx_full = b.wx_full from metar b WHERE a.metar_id = b.station_id;"
psql -d world -c "UPDATE places a SET wx_full = b.wx_full from metar b WHERE a.wx_full IS NULL AND a.metar_id2 = b.station_id;"
psql -d world -c "UPDATE places a SET wx_full = b.wx_full from metar b WHERE a.wx_full IS NULL AND a.metar_id2 = b.station_id;"

# wind
#psql -d world -c "ALTER TABLE ${mytable} ADD COLUMN wind_full text;"
#psql -d world -c "UPDATE metar a SET wind_full = (SELECT b.abbrev || ' ' || a.wind_sp || 'KT' FROM compass_points b WHERE a.wind_dir <= b.maximum AND a.wind_dir >= b.minimum);"
#psql -d world -c "UPDATE metar SET wind_full = 'N' WHERE wind_dir = 0 OR wind_dir = 360;"

