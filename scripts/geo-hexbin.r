library(dplyr)
library(ggplot2)
library(ggmap)
library(lubridate)
library(gganimate)

input.file <- "/tmp/counts"
san.francisco <- list(left=-122.55, right=-122.3549, bottom=37.7040, top=37.8324)

load.counts <- function(input.file) {
  raw.counts <- read.table(input.file, col.names = c("ts", "lon", "lat", "count"))
  counts <- raw.counts %>%
    mutate(time=as.POSIXct(ts/1000, origin="1970-01-01", 
                           timezone="America/Los_Angeles")) %>%
    group_by(time, lon, lat) %>% 
    summarize(count=max(count)) %>% 
    ungroup() %>% 
    mutate(id=row_number())
  counts
}

filter.rect <- function(df, r) {
  df %>% filter(lon >= r$left & lat >= r$bottom & lon <= r$right & lat <= r$top)
}

filter.time <- function(df, start, end) {
  df %>% filter(time >= as.POSIXct(start, timezone="America/Los_Angeles")
                & time < as.POSIXct(end, timezone="America/Los_Angeles"))
}

angles <- 0:5*(pi/3)

hexagon <- function(r, x, y, id) {
  xs <- x + r*sin(angles)
  ys <- y - r*cos(angles)
  data.frame(x=xs, y=ys, id=id)
}

bbox <- function(df, frame=0.25) {
  c(left=min(df$lon)-frame, 
    right=max(df$lon)+frame, 
    top=max(df$lat)+frame, 
    bottom=min(df$lat)-frame)
}

map.df <- function(df, zoom=10) {
  df.bb <- bbox(df, frame=0.05)
  hexagons <- df %>% group_by(id) %>% do(hexagon(1/240,.$lon,.$lat,.$id)) %>% ungroup
  datapoly <- merge(df, hexagons, by=c("id"))
  map <- get_stamenmap(df.bb, zoom = zoom, maptype = "terrain-background")
  p <- ggmap(map) + 
    geom_polygon(aes(x=x, y=y, fill=count, alpha=count, 
                     group=id, frame=strftime(time, "%B %d %H:%M")), 
                 data=datapoly, color="white") +
    theme(axis.title=element_blank()) +
    scale_fill_gradient(low="#9ECAE1", high="#08519C", trans="log") +
    scale_alpha_continuous(range=c(0.6,1), trans="log") +
    guides(fill=FALSE, alpha=FALSE)
  gg_animate(p)
}