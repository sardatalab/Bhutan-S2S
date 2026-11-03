# Load and validate raw microdata for donor (BLSS 2022) and receiver (LFS 2025).

blss.don <- read_dta(file.path(datapath, "raw", donor_file)) |>
  mutate(
    district   = as.factor(district),
    logwelfare = log(welfare),
    r_cons     = if_else(r_cons == Inf, NA_real_, r_cons)
  )

lfs.rec <- read_dta(file.path(datapath, "raw", receiver_file)) |>
  mutate(district = as.factor(as.character(district)))

# Variables only in donor or only in receiver cannot be matching covariates
vars_donor_only    <- setdiff(names(blss.don), names(lfs.rec))
vars_receiver_only <- setdiff(names(lfs.rec),  names(blss.don))

# All donor-only variables (including _c share outcomes) are excluded automatically
# via vars_donor_only above. Additional exclusions are identifiers and collinear quantities.
vars_exclude <- c(
  vars_donor_only, vars_receiver_only,
  "hhid", "year", "hhwt", "wgt", "laborinc", "laborinc_def",
  "decile_national", "share_hh_inc", "labor_pc", "labor_pc_def",
  "flag6_income2", "hh_dep_ratio", "hh_sex_ratio",
  "hh_sp_educ", "welfare", "logwelfare",
  "hh_size_age0", "hh_size_age1", "hh_size_age2", "hh_size_age3", "hh_size_age4",
  "hh_head_age", "hh_sh_age0", "hh_sh_age1", "hh_sh_age2", "hh_sh_age3", "hh_sh_age4"
)

covariates <- setdiff(names(blss.don), vars_exclude)
