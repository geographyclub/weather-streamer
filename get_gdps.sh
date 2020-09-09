#!/bin/bash

##### download #####
#dir=$PWD/../data/gdps/utc$(date -u +"%Y%m%d")
#mydate=$(date -u +"%Y%m%d")
dir=$PWD/../data/gdps
mydate=$(date +"%Y%m%d")
rm -f ${dir}/*
for a in $(seq -f "%03g" 3 3 81); do
  wget -P ${dir} https://dd.weather.gc.ca/model_gem_global/25km/grib2/lat_lon/00/${a}/CMC_glb_TMP_TGL_2_latlon.24x.24_${mydate}00_P${a}.grib2;
  wget -P ${dir} https://dd.weather.gc.ca/model_gem_global/25km/grib2/lat_lon/00/${a}/CMC_glb_PRATE_SFC_0_latlon.24x.24_${mydate}00_P${a}.grib2
  wget -P ${dir} https://dd.weather.gc.ca/model_gem_global/25km/grib2/lat_lon/00/${a}/CMC_glb_TCDC_SFC_0_latlon.24x.24_${mydate}00_P${a}.grib2
done

##### extract #####
echo "extracting gribs..."
for a in TMP PRATE TCDC; do
  ls ${dir}/*${a}*.grib2 | while read file; do
    hour=`echo ${file} | sed 's/^.*_P//g' | sed 's/.grib2//g'`
    $PWD/../data/grib2/wgrib2/wgrib2 ${file} `cat $PWD/../data/places.csv | sed -n '1,2000p' | awk -F '\t' '{print "-lon",$24,$23}' | tr '\n' ' '` | tr ':' '\n' | grep 'val=' | sed -e 's/^.*val=//g' > ${dir}/${a}${hour}.txt
    $PWD/../data/grib2/wgrib2/wgrib2 ${file} `cat $PWD/../data/places.csv | sed -n '2001,4000p' | awk -F '\t' '{print "-lon",$24,$23}' | tr '\n' ' '` | tr ':' '\n' | grep 'val=' | sed -e 's/^.*val=//g' >> ${dir}/${a}${hour}.txt
    $PWD/../data/grib2/wgrib2/wgrib2 ${file} `cat $PWD/../data/places.csv | sed -n '4001,7343p' | awk -F '\t' '{print "-lon",$24,$23}' | tr '\n' ' '` | tr ':' '\n' | grep 'val=' | sed -e 's/^.*val=//g' >> ${dir}/${a}${hour}.txt
  done
done
awk -F '\t' '{print $1}' $PWD/../data/places.csv | paste - $(ls -v ${dir}/TMP*.txt | tr '\n' ' ') $(ls -v ${dir}/PRATE*.txt | tr '\n' ' ') $(ls -v ${dir}/TCDC*.txt | tr '\n' ' ') > ${dir}/gdps_places.csv

##### psql #####
mytable=gdps
psql -d world -c "DROP TABLE IF EXISTS ${mytable};"
psql -d world -c "CREATE TABLE ${mytable}(ogc_fid int, t003 numeric, t006 numeric, t009 numeric, t012 numeric, t015 numeric, t018 numeric, t021 numeric, t024 numeric, t027 numeric, t030 numeric, t033 numeric, t036 numeric, t039 numeric, t042 numeric, t045 numeric, t048 numeric, t051 numeric, t054 numeric, t057 numeric, t060 numeric, t063 numeric, t066 numeric, t069 numeric, t072 numeric, t075 numeric, t078 numeric, t081 numeric, p003 numeric, p006 numeric, p009 numeric, p012 numeric, p015 numeric, p018 numeric, p021 numeric, p024 numeric, p027 numeric, p030 numeric, p033 numeric, p036 numeric, p039 numeric, p042 numeric, p045 numeric, p048 numeric, p051 numeric, p054 numeric, p057 numeric, p060 numeric, p063 numeric, p066 numeric, p069 numeric, p072 numeric, p075 numeric, p078 numeric, p081 numeric, c003 numeric, c006 numeric, c009 numeric, c012 numeric, c015 numeric, c018 numeric, c021 numeric, c024 numeric, c027 numeric, c030 numeric, c033 numeric, c036 numeric, c039 numeric, c042 numeric, c045 numeric, c048 numeric, c051 numeric, c054 numeric, c057 numeric, c060 numeric, c063 numeric, c066 numeric, c069 numeric, c072 numeric, c075 numeric, c078 numeric, c081 numeric);"
psql -d world -c "COPY ${mytable} FROM '${dir}/gdps_places.csv' DELIMITER E'\t' CSV;"
psql -d world -c "ALTER TABLE ${mytable} ADD COLUMN id serial primary key;"
psql -d world -c "UPDATE ${mytable} SET t003 = round((t003-273.15)); UPDATE ${mytable} SET t006 = round((t006-273.15)); UPDATE ${mytable} SET t009 = round((t009-273.15)); UPDATE ${mytable} SET t012 = round((t012-273.15)); UPDATE ${mytable} SET t015 = round((t015-273.15)); UPDATE ${mytable} SET t018 = round((t018-273.15)); UPDATE ${mytable} SET t021 = round((t021-273.15)); UPDATE ${mytable} SET t024 = round((t024-273.15)); UPDATE ${mytable} SET t027 = round((t027-273.15)); UPDATE ${mytable} SET t030 = round((t030-273.15)); UPDATE ${mytable} SET t033 = round((t033-273.15)); UPDATE ${mytable} SET t036 = round((t036-273.15)); UPDATE ${mytable} SET t039 = round((t039-273.15)); UPDATE ${mytable} SET t042 = round((t042-273.15)); UPDATE ${mytable} SET t045 = round((t045-273.15)); UPDATE ${mytable} SET t048 = round((t048-273.15)); UPDATE ${mytable} SET t051 = round((t051-273.15)); UPDATE ${mytable} SET t054 = round((t054-273.15)); UPDATE ${mytable} SET t057 = round((t057-273.15)); UPDATE ${mytable} SET t060 = round((t060-273.15)); UPDATE ${mytable} SET t063 = round((t063-273.15)); UPDATE ${mytable} SET t066 = round((t066-273.15)); UPDATE ${mytable} SET t069 = round((t069-273.15)); UPDATE ${mytable} SET t072 = round((t072-273.15)); UPDATE ${mytable} SET t075 = round((t075-273.15)); UPDATE ${mytable} SET t078 = round((t078-273.15)); UPDATE ${mytable} SET t081 = round((t081-273.15));"

##### daily gdps #####
rm -f $PWD/../data/places_utc.sql
psql -d world -c "\COPY (SELECT DISTINCT(utc), day1, day2, day3 FROM places_utc) TO STDOUT (DELIMITER E'\t');" | while IFS=$'\t' read -a array; do echo '\COPY (SELECT a.ogc_fid, LEAST('$(echo ${array[1]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.t\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[1]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.t\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[2]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.t\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[2]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.t\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[3]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.t\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[3]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.t\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[1]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.p\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[1]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.p\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[2]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.p\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[2]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.p\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[3]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.p\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[3]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.p\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[1]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.c\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[1]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.c\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[2]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.c\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[2]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.c\1/g' -e 's/$/)/g')', LEAST('$(echo ${array[3]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.c\1/g' -e 's/$/)/g')', GREATEST('$(echo ${array[3]} | sed -e 's/000 //g' -e 's/ /,/g' -e 's/\([0-9][0-9][0-9]\)/a.c\1/g' -e 's/$/)/g')' FROM gdps a, places_utc b WHERE a.ogc_fid = b.ogc_fid AND b.utc = '\'$(echo ${array[0]})\'') TO STDOUT;' >> $PWD/../data/places_utc.sql; done
psql -d world -f $PWD/../data/places_utc.sql > $PWD/../data/places_gdps_utc.csv
psql -d world -c "DROP TABLE IF EXISTS places_gdps_utc;"
psql -d world -c "CREATE TABLE places_gdps_utc(ogc_fid int, day1_tmin numeric, day1_tmax numeric, day2_tmin numeric, day2_tmax numeric, day3_tmin numeric, day3_tmax numeric, day1_pmin numeric, day1_pmax numeric, day2_pmin numeric, day2_pmax numeric, day3_pmin numeric, day3_pmax numeric, day1_cmin numeric, day1_cmax numeric, day2_cmin numeric, day2_cmax numeric, day3_cmin numeric, day3_cmax numeric);"
psql -d world -c "COPY places_gdps_utc FROM '$PWD/../data/places_gdps_utc.csv' CSV DELIMITER E'\t';"

##### conditions #####
psql -d world -c "ALTER TABLE places_gdps_utc ADD COLUMN IF NOT EXISTS day1_wx text, ADD COLUMN IF NOT EXISTS day2_wx text, ADD COLUMN IF NOT EXISTS day3_wx text;"
psql -d world -c "UPDATE places_gdps_utc SET day1_wx = CASE WHEN day1_pmax > 0 AND day1_tmin > 0 THEN 'RAIN' WHEN day1_pmax > 0 AND day1_tmin <= 0 THEN 'SNOW' WHEN day1_pmax <= 0 AND day1_cmax <= 10 THEN 'CLEAR' WHEN day1_pmax <= 0 AND day1_cmax > 10 AND day1_cmax < 50 THEN 'PARTLY CLOUDY' WHEN day1_pmax <= 0 AND day1_cmax >= 50 THEN 'CLOUDY' ELSE '' END;"
psql -d world -c "UPDATE places_gdps_utc SET day2_wx = CASE WHEN day2_pmax > 0 AND day2_tmin > 0 THEN 'RAIN' WHEN day2_pmax > 0 AND day2_tmin <= 0 THEN 'SNOW' WHEN day2_pmax <= 0 AND day2_cmax <= 10 THEN 'CLEAR' WHEN day2_pmax <= 0 AND day2_cmax > 10 AND day2_cmax < 50 THEN 'PARTLY CLOUDY' WHEN day2_pmax <= 0 AND day2_cmax >= 50 THEN 'CLOUDY' ELSE '' END;"
psql -d world -c "UPDATE places_gdps_utc SET day3_wx = CASE WHEN day3_pmax > 0 AND day3_tmin > 0 THEN 'RAIN' WHEN day3_pmax > 0 AND day3_tmin <= 0 THEN 'SNOW' WHEN day3_pmax <= 0 AND day3_cmax <= 10 THEN 'CLEAR' WHEN day3_pmax <= 0 AND day3_cmax > 10 AND day3_cmax < 50 THEN 'PARTLY CLOUDY' WHEN day3_pmax <= 0 AND day3_cmax >= 50 THEN 'CLOUDY' ELSE '' END;"

