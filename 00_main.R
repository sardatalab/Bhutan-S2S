  # ==============================================================================
  # Bhutan Survey-to-Survey Imputation — Master Script
  # Run this file only. All child scripts are sourced from code/
  #
  # Authors: Ivan Gachet (igachet@worldbank.org)
  #          Jaime Fernandez (jfernandezromero@worldbank.org)
  # Updated: March 2026
  # ==============================================================================

  rm(list = ls())

  # ------------------------------------------------------------------------------
  # CHANGE THIS PATH to the folder containing this package on your machine
  # ------------------------------------------------------------------------------
  #base_path <- "C:/Users/wb483231/OneDrive - WBG/Desktop/S2S_BHUTAN"
  #base_path <- "C:/Users/wb483231/OneDrive - WBG/FY2025-26/CEQ/Bhutan/survey_to_survey"
  base_path <- "D:/Dropbox/world bank/FY 2025-26/CEQ/Buthan/survey_to_survey"


  codepath <- file.path(base_path, "code")
  datapath <- file.path(base_path, "data")
  outpath  <- file.path(base_path, "output")

  dir.create(file.path(datapath, "raw"),       showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(datapath, "temp"),      showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(datapath, "processed"), showWarnings = FALSE, recursive = TRUE)
  dir.create(outpath,                          showWarnings = FALSE, recursive = TRUE)

  # ------------------------------------------------------------------------------
  # PACKAGES — installed automatically on first run
  # ------------------------------------------------------------------------------
  packages <- c(
    "StatMatch", "survey", "questionr", "reldist", "glmnet", "useful",
    "data.table", "haven", "statar", "parallel", "foreach", "doParallel",
    "dplyr", "tidyr", "dineq", "convey", "renv", "transport", "ggridges",
    "ggplot2", "forcats", "scales", "readxl", "Hmisc", "xgboost",
    "matrixStats", "ggh4x"
  )
  installed <- rownames(installed.packages())
  for (pkg in packages[!packages %in% installed]) {
    install.packages(pkg, dependencies = TRUE)
  }
  lapply(packages, require, character.only = TRUE)

  # ------------------------------------------------------------------------------
  # GLOBAL PARAMETERS
  # ------------------------------------------------------------------------------
  nsim <- 100   # number of simulation iterations
  n.a  <- 0.9   # bootstrap resampling rate
  seed <- 1729
  agg.fun <- "median"   # aggregation across simulations: "median" or "mean"

  # Input data filenames — expected format: clean_SURVEYNAME_YEAR.dta
  # Change these two lines when switching datasets
  donor_file    <- "clean_BLSS_2022.dta"   # donor survey, placed in data/raw/
  receiver_file <- "clean_LFS_2025.dta"    # receiver survey, placed in data/raw/

  # Parse survey name and year from filenames automatically
  donor_parts    <- strsplit(tools::file_path_sans_ext(donor_file),    "_")[[1]]
  receiver_parts <- strsplit(tools::file_path_sans_ext(receiver_file), "_")[[1]]
  donor_survey   <- donor_parts[2]                 # e.g. BLSS
  donor_year     <- as.integer(donor_parts[3])     # e.g. 2022
  receiver_survey <- receiver_parts[2]             # e.g. LFS
  receiver_year   <- as.integer(receiver_parts[3]) # e.g. 2025

  # Label shared by all output filenames: type_DONOR_to_RECEIVER_distance.ext
  survey_label <- paste0(donor_survey, "_", donor_year,
                        "_to_", receiver_survey, "_", receiver_year)

  # Matching variables and donor variables — HHs WITH labour income
  X.mtc.income    <- c("labor_pc_def", "hh_size", "hhb_year")
  #X.mtc.income    <- c("ymatch", "hh_size", "hh_head_age","hh_head_age_sq")
  don.vars.income <- c("r_cons", "r_nlabor", "r_rem", "r_pens", "r_cap", "r_sp","r_renta","r_durables","r_gift","r_food")

  # Matching variables and donor variables — HHs WITHOUT labour income
  # _c suffix = consumption shares in donor; converted to levels in 03_simulation_noincome.R
  # All match variables must exist in both donor and receiver surveys
  X.mtc.noincome    <- c("ymatch", "hh_size", "hhb_year")
  #X.mtc.noincome    <- c("ymatch", "hh_size", "hh_head_age","hh_head_age_sq")
  don.vars.noincome <- c("welfare", "r_nlabor_c", "r_rem_c", "r_pens_c", "r_cap_c", "r_sp_c","r_renta_c","r_durables_c","r_gift_c","r_food_c")

  # Distance function for hot-deck matching — set independently per group
  # Options: "Mahalanobis", "Euclidean", "Canberra", "Manhattan", "Gower", "minimax"
  dist.fun.income   <- "Mahalanobis"
  dist.fun.noincome <- "Mahalanobis"

  # Distance suffix encodes matching choices in output filenames
  #dist_suffix <- if (dist.fun.income == dist.fun.noincome) {
  #  dist.fun.income
  #} else {
  #  paste0("inc", dist.fun.income, "_noinc", dist.fun.noincome)
  #}

  # Output filename for imputed dataset
  # out_filename <- paste0("imputed_", survey_label, "_", dist_suffix, ".dta")
  #file_label <- paste0(survey_label, "_", dist_suffix)
out_filename <- paste0("imputed_", survey_label, "_", ".dta")
file_label <- paste0(survey_label)


  # Price deflators to convert donor-year values to 2021 PPP
  cpi21 <- 1.049713   # CPI adjustment to 2021 PPP base
  icp21 <- 21.36116   # PPP conversion factor (as used in GMD)

  # National accounts private consumption growth from donor to receiver year.
  # Add a new entry here when introducing a new donor/receiver year combination.
  na_growth_lookup <- list(
    "2022_2018" = 0.9526,	
    "2022_2019" = 0.9794,	
    "2022_2020" = 0.9851,	
    "2022_2021" = 0.9883,	
    "2022_2022" = 1.0000,
    "2022_2023" = 1.0607,
    "2022_2024" = 1.0858,
    "2022_2025" = 1.1454
  )
  growth_key <- paste0(donor_year, "_", receiver_year)
  na_growth  <- na_growth_lookup[[growth_key]]
  if (is.null(na_growth)) stop(
    "No growth factor defined for ", growth_key,
    ". Add it to na_growth_lookup in 00_main.R."
  )

  # Poverty lines in 2017 PPP USD/day and national poverty line in BTN/month
  pov_line_low  <- 3.0
  pov_line_mid  <- 4.2
  pov_line_high <- 8.3
  npl           <- 6204

  # ------------------------------------------------------------------------------
  # RUN
  # ------------------------------------------------------------------------------
  source(file.path(codepath, "01_load_data.R"))
  #source(file.path(codepath, "02_simulation_income.R"))
  source(file.path(codepath, "02_simulation_income_Opt_D.R"))
  #source(file.path(codepath, "03_simulation_noincome.R"))
  source(file.path(codepath, "03_simulation_noincome_Opt_D.R"))
  source(file.path(codepath, "04_combine_results.R"))
  source(file.path(codepath, "05_outputs.R"))
