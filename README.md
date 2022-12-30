---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->


# neon-beetles-forecasts

<!-- badges: start -->
<!-- badges: end -->

This repository hosts the code for my submissions to the [EFI NEON Forecasting Challenge](https://projects.ecoforecast.org/neon4cast-docs/).

These forecasts are made for mostly exploratory and educational purposes, emphasizing simplicity and the illustration of various forecasting concepts over technical accuracy.
This repository includes a range of forecasts of varying complexity.
Each forecast focuses on introducing a different strategy into the modeling.
An earnest attempt to produce the best forecast would draw on several of these approaches after evaluating the relative performance of each.
All forecasts here are probabilistic: representing uncertainty is an essential component of forecasting and a crucial element of the EFI challenge.



# Overview of the beetles challenge

The beetles forecast challenge seeks to predict the mean observed species richness and relative total abundance (measured as the average number of beetles caught per trap night) in the biweekly samples across the 47 terrestrial sites in the NEON network.  
Each site consists of 30-40 individual traps spread over 10 plots.
Details for the beetles forecast challenge can be found under the [official EFI documentation](https://projects.ecoforecast.org/neon4cast-docs/theme-beetle-communities.html)

# Summary of the forecast models

## `cb_f1`: historical means

Perhaps the simplest possible forecast is a prediction based only on historical averages.  There are still many ways to compute such averages depending on how data are grouped by plot, site, time period, etc.  The simple model used here considers site-wide weekly averages.

## `cb_f2`: ARIMA

A simple mechanism to reflect periodic or otherwise seasonal trends is through an ARIMA model

## `cb_f3`: National ARIMA

Beetle sample data is very noisy at the site level, but shows a much clearer periodic trend at the national level.

![](img/national_ave.png)


## `cb_f4`: Weather drivers



Weather probably plays a key role in beetle activity, which in turn is a strong predictor of trap volumes (and thus richness and abundance).  While most traps see the maximum activity in summer months, site-level weather co-variates may give more predictive power than merely knowing the month or week in the year. Adding weather co-variates creates an interesting challenge for forecasting because true forecasts of the beetle data are then contingent on also effectively forecasting the weather data.  This example illustrates the integration of both historical weather measurements made at each site as well as making predictions for the coming month based on NOAA long-range 35 day forecasts.


## `cb_f5`: Machine-learning predictions

**Not Implemented**


## `cb-f6`: Observation process model

**Not Implemented**

## `cb-f7`: Population dynamics process model

**Not Implemented**

