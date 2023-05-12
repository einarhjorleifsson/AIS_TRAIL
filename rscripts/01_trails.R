# ------------------------------------------------------------------------------
# run this in terminal as:
#  nohup R < R/01_trails.R --vanilla > logs/01_trails_YYYY_MM-DD.log &

lubridate::now()

library(data.table)
library(sf)
library(mapdeck)
source("~/R/Pakkar2/ramb/TOPSECRET.R")
library(tidyverse)
options(ggplot2.continuous.colour = "viridis")
options(ggplot2.continuous.fill = "viridis")
library(ramb)
library(omar)
library(argosfilter)

island <- 
  gisland::read_strandlinur() |> 
  mutate(area = st_area(geom)) |> 
  filter(area == max(area)) |> 
  mutate(on_land = TRUE) |> 
  select(on_land) |> 
  st_transform(crs = 3057) |> 
  st_buffer(dist = -100) |> 
  st_transform(crs = 4326)

harbour <- 
  sf::read_sf("~/stasi/gis/harbours/gpkg/harbours-hidstd_2023-05-11.gpkg")
harbours.standards <- 
  readxl::read_excel("~/stasi/gis/harbours/data-raw/stk_harbours.xlsx") |> 
  select(hid, hid_std)
con <- connect_mar()

YEARS <- 2007:2023
D1 <- paste0(min(YEARS), "-01-01")
D2 <- paste0(max(YEARS), "-12-31")

# Make the connection for each fishing vessel trail ----------------------------
vessels <- 
  omar::ln_agf(con) |> 
  filter(between(date, to_date(D1, "YYYY-MM-DD"), to_date(D2, "YYYY-MM-DD"))) |> 
  filter(!between(vid, 3700, 4999)) |>
  filter(vid > 0) |> 
  group_by(vid) |> 
  summarise(wt = sum(wt, na.rm = TRUE) / 1e3,
            .groups = "drop") |> 
  filter(wt > 0) |> 
  left_join(omar:::stk_midvid(con) |> 
              select(mid, vid, t1, t2, pings),
            by = "vid")
vessels |> 
  collect(n = Inf) |> 
  filter(is.na(mid)) |> 
  knitr::kable(caption = "Vessels with no mid-match")

trail <-
  vessels |> 
  filter(!is.na(mid)) |> 
  select(vid, mid, t1, t2) |> 
  mutate(t1 = to_date(t1, "YYYY:MM:DD"),
         t2 = to_date(t2, "YYYY:MM:DD")) |> 
  left_join(omar::stk_trail(con),
            by = "mid") |> 
  filter(time >= t1 & time <= t2)

# Extract trail by vessel ------------------------------------------------------
VID <- 
  vessels |> 
  filter(!is.na(mid)) |> 
  collect(n = Inf) |> 
  pull(vid) |> 
  sort() |> 
  unique()

v_counter <- list()
for(v in 1:length(VID)) {
  VIDv <- VID[v]
  print(VIDv)
  trailv <- 
    trail |> 
    filter(vid == VIDv) |> 
    select(-c(t1, t2)) |> 
    collect(n = Inf) |> 
    arrange(time) |> 
    filter(between(lon, -35, 30),
           between(lat, 50, 79)) %>%
    left_join(harbours.standards,
              by = "hid") |> 
    st_as_sf(coords = c("lon", "lat"),
             crs = 4326,
             remove = FALSE) |> 
    st_join(harbour) |> 
    st_join(island) |> 
    st_drop_geometry() |> 
    # 2023-05-12: 
    #             if point in harbour, then not on land
    # mutate(on_land = replace_na(on_land, FALSE)) |> 
    mutate(on_land = case_when(!is.na(hid_std.y)  & on_land == TRUE ~ FALSE,
                               is.na(hid_std.y)   & on_land == TRUE ~ TRUE,
                               .default = FALSE)) |> 
    # The order matters
    arrange(vid, time, hid_std.x, io) |> 
    mutate(.rid = 1:n())
  tmp <- 
    trailv |> 
    filter(!on_land) |> 
    distinct(time, .keep_all = TRUE)
  removed <- 
    trailv |> 
    filter(!.rid %in% tmp$.rid)
  
  trailv <- 
    tmp |> 
    # cruise id (aka tripid), negative values: in harbour
    mutate(.cid = ramb::rb_trip(!is.na(hid_std.y))) |>
    group_by(vid, .cid) |> 
    mutate(trip.n = 1:n()) |> 
    ungroup() |> 
    mutate(hid_dep = hid_std.y,
           hid_arr = hid_std.y) |> 
    group_by(vid) |> 
    fill(hid_dep, .direction = "down") |> 
    fill(hid_arr, .direction = "up") |> 
    ungroup() |> 
    filter(between(year(time), 2007, 2023)) |> 
    select(vid, time, .cid, lon, lat, speed, hid_dep, hid_arr, .rid, trip.n) |> 
    # filter(.cid > 0) |> 
    group_by(vid, .cid) |> 
    mutate(pings = n()) |> 
    mutate(v = ifelse(pings > 5 & .cid > 0,
                      # Note: FIRST arguement is lat
                      vmask(lat, lon, time, vmax = rb_kn2ms(30)),
                      "short")) |> 
    ungroup() |> 
    mutate(v = as.character(v)) |> 
    select(-pings)
  
  trailv <-
    bind_rows(trailv,
              removed |> 
                mutate(v = case_when(on_land == TRUE ~ "removed on land",
                                     .default = "removed time duplicate")) |> 
                select(vid, time, lon, lat, speed, .rid, v)) |> 
              arrange(.rid)
              
              
              # split the data by year, because downstream we want to collate the data by
              #  year for all vessels
              YEARS <- year(min(trailv$time)):year(max(trailv$time))
              for(y in 1:length(YEARS)) {
                pth <- paste0("data/trips_y", YEARS[y], "_v", str_pad(VIDv, width = 4, pad = "0"), ".rds") 
                tmp <- trailv |> filter(year(time) == YEARS[y]) 
                if(nrow(tmp) > 0) tmp |> write_rds(pth)
              }
}


lubridate::now()

devtools::session_info()


