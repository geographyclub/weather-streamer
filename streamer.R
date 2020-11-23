### libraries
library(rpostgis)
library(RPostgreSQL)
library(rmapshaper)
library(sf)
library(smoothr)


### get data
db <- dbConnect(dbDriver("PostgreSQL"), user = 'steve', dbname = 'world')
countries <- pgGetGeom(db, c("public", "countries"), geom = "wkb_geometry", gid = "ogc_fid", query=NULL)
#states <- st_read('/home/steve/Public/maps/naturalearth/10m_cultural/ne_10m_admin_1_states_provinces_lakes.shp', layer='ne_10m_admin_1_states_provinces_lakes')



### smooth
#countries_smooth <- smooth(countries, method="chaikin", refinements=2)
countries_simple <- ms_simplify(countries, keep = 0.015)
states_simple <- ms_simplify(states, keep = 0.015)


### export
pgInsert(conn, name = "roads_simple", data.obj = roads_simple, overwrite = TRUE)
states <- st_write(states_simple, delete_layer=TRUE, '/home/steve/Public/maps/naturalearth/10m_cultural/ne_10m_admin_1_states_provinces_lakes_simple.shp')


### end session
RPostgreSQL::dbDisconnect(conn)