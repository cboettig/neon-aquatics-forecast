## simulate production of a forecast produced each day of the past year



## ----setup------------------------------------------------------------------------------------------------
library(neonstore)
library(neon4cast) # remotes::install_github("eco4cast/neon4cast", dep=TRUE)
library(tidyverse)
library(tsibble)
library(lubridate)
library(fable)
library(glue)

## ---------------------------------------------------------------------------------------------------------
targets <-
  glue("https://data.ecoforecast.org/neon4cast-targets/",
       "{theme}/{theme}-targets.csv.gz", theme="aquatics") |>
  read_csv(show_col_types = FALSE)

targets_ts <- targets |>
  pivot_wider(names_from="variable", values_from="observation") |>
  as_tsibble(index = datetime, key = site_id)


sites <- unique(targets_ts$site_id)
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


forecast_date <- Sys.Date() - days(35)

weather_fc <- function(forecast_date, targets_ts, history) {
  past <-
    targets_ts |>
    filter(datetime < forecast_date)
  past2 <- left_join(past, as_tsibble(history, datetime, key=site_id) ) |>
    select(temperature, air_temperature, oxygen)

  future <- noaa_stage2() |>
    filter(reference_datetime == lubridate::as_datetime(forecast_date),
           variable %in% c("air_temperature"),
           site_id %in% sites) |>
    mutate(date = lubridate::as_date(datetime)) |>
    group_by(site_id, date, variable) |>
    summarise(mean = mean(prediction, na.rm=TRUE),
              .groups = "drop") |>
    collect() |>
    pivot_wider(c(site_id, date),
                names_from="variable",
                values_from = "mean") |>
    mutate(air_temperature = air_temperature -273)  |>
    rename(datetime = date)


  ## ---------------------------------------------------------------------------------------------------------
  new_data <- future |>
    as_tsibble(datetime, key=site_id)

  ## ---------------------------------------------------------------------------------------------------------
  fc_temperature <-
    past2  |>
    select(temperature, air_temperature) |>
    drop_na() |>
    fill_gaps() |>
    model(tslm = TSLM(temperature ~ air_temperature)) |>
    forecast(new_data = new_data)

  ## ---------------------------------------------------------------------------------------------------------

  new_data2 <- left_join(new_data, fc_temperature) |>
    select(site_id, datetime, air_temperature, temperature = .mean)


  fc_oxygen <- past2  |> drop_na() |> fill_gaps() |>
    model(tslm = TSLM(oxygen ~ temperature  ) ) |>
    forecast(new_data = new_data2) |>
    select(site_id, datetime, oxygen, .model, .mean)

  ## ---------------------------------------------------------------------------------------------------------

  fc_temperature <- fc_temperature |> select(-air_temperature)

  forecast <- bind_rows(efi_format(fc_temperature),
                        efi_format(fc_oxygen))


  ## ---------------------------------------------------------------------------------------------------------
  scores <- score(forecast, targets)

  write_csv(scores, "scores.csv", append=TRUE)

  gc()
}

# initialize csv
 tibble("model_id" = character(), "site_id" = character(),
                 "datetime" = POSIXct(),
                 "family" = character(), "variable" = character(),
                 "observation" = numeric(), "crps" = numeric(),
                 "logs" = numeric(), "mean" = numeric(), "median" = numeric(),
                 "sd" = numeric(), "quantile97.5" = numeric(),
                 "quantile02.5" = numeric(), "quantile90" = numeric(),
                 "quantile10"  = numeric(), "reference_datetime"  = numeric(),
                 "horizon" = numeric()) |>
   write_csv("scores.csv")

ref_dates <- seq( (Sys.Date() - months(12)), Sys.Date(), by = 1)

# pick up from previous
#scores <- read_csv("scores.csv")
#ref_dates <- ref_dates[ref_dates > max(scores$reference_datetime)]

scores <- map_dfr(ref_dates, possibly(weather_fc),
                  targets_ts=targets_ts,
                  history=history)

##

scores |>
  group_by(reference_datetime, variable) |>
  summarise(crps = mean(crps,na.rm=TRUE),
            logs = mean(logs, na.rm=TRUE)) |>
  pivot_longer(c(crps, logs), names_to="metric", values_to="score") |>
  ggplot(aes(reference_datetime, score, col=variable)) +
  geom_line() + facet_wrap(~metric)


