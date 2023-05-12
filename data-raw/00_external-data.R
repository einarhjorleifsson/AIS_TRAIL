# ------------------------------------------------------------------------------
# run this in terminal as:
#  nohup R < data-raw/00_external-data.R --vanilla > lgs/00_external-data_YYYY-MM-DD.log &


# nohup R < rscripts/01_stk-trails.R --vanilla > lgs/01_stk-trails_YYYY_MM-DD.log &
lubridate::now()
library(sf)
library(tidyverse)
library(gisland)

gisland::read_strandlinur() |> 
  mutate(area = st_area(geom)) |> 
  filter(area == max(area)) |> 
  mutate(on_land = TRUE) |> 
  select(on_land) |> 
  st_transform(crs = 3057) |> 
  st_buffer(dist = -100) |> 
  st_transform(crs = 4326) |> 
  st_write("data-raw/island.gpkg")

sf::read_sf("~/stasi/gis/harbours/gpkg/harbours-hidstd_2023-05-02.gpkg") |> 
  st_write("data-raw/harbours-hidstd.gpkg")
readxl::read_excel("~/stasi/gis/harbours/data-raw/stk_harbours.xlsx") |> 
  write_csv("data-raw/stk_harbours.csv")

devtools::session_info()


