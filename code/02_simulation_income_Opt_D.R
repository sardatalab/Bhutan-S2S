# Option D variant of 02_simulation_income.R
# log-transforms labor_pc_def before distance computation in RANDwNND.hotdeck.
# Original (untransformed) labor_pc_def is preserved for welfare computation.
# Receiver values are clipped to donor support after log-transformation.
# All other logic is identical to 02_simulation_income.R.

set.seed(seed)

vars_to_impute <- c("welfare", "y_nl", "y_rem", "y_pens", "y_cap", "y_sp", "y_renta", "y_durables", "y_gift", "y_food")

sim_income <- lapply(vars_to_impute, function(v) {
  subset(lfs.rec, flag6_income2 == 0, select = "hhid")
})
names(sim_income) <- vars_to_impute

# log_labor_pc_def used for matching only — original labor_pc_def kept for welfare
X.mtc.income.D <- c("log_labor_pc_def", "hh_size", "hhb_year")

for (sim in seq_len(nsim)) {
  set.seed(seed + sim)
  message("[Income group - Opt D] Simulation ", sim, " of ", nsim)

  train <- blss.don |>
    filter(flag6_income2 == 0) |>
    group_by(district) |>
    sample_frac(n.a) |>
    ungroup() |>
    as.data.frame() |>
    mutate(log_labor_pc_def = log(labor_pc_def + 1))

  # Clip receiver to donor support after log-transformation
  don_range <- range(train$log_labor_pc_def, na.rm = TRUE)

  recv <- lfs.rec[lfs.rec$flag6_income2 == 0, ] |>
    as.data.frame() |>
    mutate(log_labor_pc_def = pmax(pmin(log(labor_pc_def + 1), don_range[2]), don_range[1]))

  group.v <- if (min(table(train$district, train$urban)) > 0) {
    c("district", "urban")
  } else {
    #c("district")
    c("urban")
  }

  rnd <- RANDwNND.hotdeck(
    data.rec   = recv,
    data.don   = train,
    match.vars = X.mtc.income.D,
    don.class  = group.v,
    dist.fun   = dist.fun.income,
    cut.don    = "min"
  )

  fused <- create.fused(
    data.rec = recv,
    data.don = train,
    mtc.ids  = rnd$mtc.ids,
    z.vars   = don.vars.income
  ) |>
    # Use original (untransformed) labor_pc_def for welfare computation
    mutate(
      welfare    = r_cons         * labor_pc_def,
      y_nl       = r_nlabor       * labor_pc_def,
      y_rem      = r_rem          * labor_pc_def,
      y_pens     = r_pens         * labor_pc_def,
      y_cap      = r_cap          * labor_pc_def,
      y_sp       = r_sp           * labor_pc_def,
      y_renta    = r_renta        * labor_pc_def,
      y_durables = r_durables     * labor_pc_def,
      y_gift     = r_gift         * labor_pc_def,
      y_food     = r_food
    )

  for (v in vars_to_impute) {
    col <- fused[, c("hhid", v)]
    names(col)[2] <- paste0(v, "_", sim)
    sim_income[[v]] <- merge(sim_income[[v]], col, by = "hhid")
  }

  rm(train, recv, rnd, fused)
}

# Aggregate per-household across simulations using agg.fun (set in 00_main.R)
lfs.imp.0 <- lfs.rec[lfs.rec$flag6_income2 == 0, ]

for (v in vars_to_impute) {
  mat <- sim_income[[v]][, -1]
  medians <- data.frame(
    hhid  = sim_income[[v]]$hhid,
    value = apply(as.matrix(mat), 1, agg.fun, na.rm = TRUE)
  )
  names(medians)[2] <- v
  lfs.imp.0 <- merge(lfs.imp.0, medians, by = "hhid", all.x = TRUE)
}

lfs.imp.0 <- lfs.imp.0 |>
  mutate(logwelfare = log(welfare))

rm(sim_income)