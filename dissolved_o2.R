
## Comparison: Dissolved oxygen inference

library(neonstore)
library(neon4cast) # remotes::install_github("eco4cast/neon4cast", dep=TRUE)
library(tidyverse)
library(tsibble)
library(lubridate)
library(fable)
library(glue)
library(rMR)
targets <-
  glue("https://data.ecoforecast.org/neon4cast-targets/",
       "{theme}/{theme}-targets.csv.gz", theme="aquatics") |>
  read_csv(show_col_types = FALSE)

site_data <-
  glue("https://raw.githubusercontent.com/eco4cast/neon4cast-targets/",
       "main/NEON_Field_Site_Metadata_20220412.csv") |>
  read_csv() |>
  filter(aquatics == 1) |>
  select(site_id = field_site_id, elevation = field_mean_elevation_m)

sites <- unique(targets$site_id)
forecast_date <- Sys.Date() - 35

future <- noaa_stage2() |>
  filter(reference_datetime == lubridate::as_datetime(forecast_date),
         variable %in% c("air_temperature"),
         site_id %in% sites) |>
  mutate(date = lubridate::as_date(datetime)) |>
  group_by(site_id, date, variable, parameter) |>
  summarise(mean = mean(prediction, na.rm=TRUE),
            .groups = "drop") |>
  collect() |>
  pivot_wider(c(site_id, date, parameter),
              names_from="variable",
              values_from = "mean") |>
  mutate(air_temperature = air_temperature -273)  |>
  rename(datetime = date)


history <-
  noaa_stage3() |>
  mutate(date = lubridate::as_date(datetime)) |>
  group_by(site_id, date, variable) |>
  summarise(mean = mean(prediction, na.rm=TRUE),
            .groups = "drop") |>
  filter(site_id %in% sites,
         variable %in% c("air_temperature")) |>
  collect() |>
  pivot_wider(c(site_id, date), names_from="variable", values_from = "mean") |>
  mutate(air_temperature = air_temperature -273) |>
  rename(datetime = date)

past <- targets |>
  pivot_wider(c(site_id, datetime),
              names_from="variable",
              values_from = "observation") |>
  left_join(history)

fit <- lm(temperature ~ air_temperature, data = past)

dissolved_oxygen <- function(temperature, elevation) {
  rMR::Eq.Ox.conc(temperature,
                  elevation.m = elevation,
                  bar.press = NULL,
                  bar.units = NULL,
                  out.DO.meas = "mg/L",
                  salinity = 0,
                  salinity.units = "pp.thou")
}


forecast <-
  left_join(future, site_data) |>
  mutate(temperature = predict(fit, tibble(air_temperature))) |>
  rowwise() |>
  mutate(temperature = max(temperature, 0),
         oxygen = dissolved_oxygen(temperature, elevation)) |>
  select(site_id, datetime, parameter, temperature, oxygen) |>
  pivot_longer(c(temperature, oxygen),
               names_to = "variable",
               values_to="prediction"
  ) |>
  mutate(family="ensemble")


scores <- score(forecast,targets)
scores |>
  score4cast::include_horizon(allow_difftime = TRUE) |>
  group_by(variable) |>
  summarise(crps = mean(crps, na.rm=TRUE),
            logs = mean(logs, na.rm=TRUE))
