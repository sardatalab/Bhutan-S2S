# Option D variant of 03_simulation_noincome.R
# log-transforms ymatch (XGBoost predictions) before distance computation.
# Receiver log_ymatch is clipped to donor support before matching.
# All other logic is identical to 03_simulation_noincome.R.

# ------------------------------------------------------------------------------
# Step 1: Parallel hyperparameter tuning on the full donor data
# ------------------------------------------------------------------------------

mod_formula <- as.formula(paste("logwelfare ~", paste(covariates, collapse = " + ")))

don_noinc    <- blss.don[blss.don$flag6_income2 == 1, c("logwelfare", covariates)]
X_train_full <- model.matrix(mod_formula, data = don_noinc)
y_train_full <- don_noinc$logwelfare

base_params <- list(
  objective   = "reg:squarederror",
  eval_metric = "rmse",
  eta         = 0.1
)

param_grid <- expand.grid(
  max_depth        = c(3, 5, 7),
  gamma            = c(0, 0.1, 0.3),
  subsample        = c(0.7, 0.8, 0.9),
  colsample_bytree = c(0.6, 0.8, 1.0)
)

n_cores <- parallel::detectCores() - 1
cl <- makeCluster(n_cores)
registerDoParallel(cl)

tuning_results <- foreach(
  i        = 1:nrow(param_grid),
  .combine  = rbind,
  .packages = "xgboost"
) %dopar% {
  dtrain <- xgb.DMatrix(data = X_train_full, label = y_train_full)
  params <- c(base_params, as.list(param_grid[i, ]))
  cv <- xgb.cv(params = params, data = dtrain,
               nrounds = 1000, nfold = 5,
               early_stopping_rounds = 100, verbose = 0)
  best_iter <- cv$best_iteration
  if (is.null(best_iter)) best_iter <- nrow(cv$evaluation_log)
  data.frame(param_grid[i, ],
             best_rmse      = cv$evaluation_log$test_rmse_mean[best_iter],
             best_iteration = best_iter)
}

stopCluster(cl)
rm(X_train_full, y_train_full, don_noinc)

write.csv(tuning_results,
          file.path(datapath, "temp", paste0("XGB_tuning_", survey_label, "_OptD.csv")),
          row.names = FALSE)

best_row <- tuning_results[which.min(tuning_results$best_rmse), ]
best_params <- c(base_params, list(
  max_depth        = best_row$max_depth,
  gamma            = best_row$gamma,
  subsample        = best_row$subsample,
  colsample_bytree = best_row$colsample_bytree
))

# ------------------------------------------------------------------------------
# Step 2: Simulation loop
# ------------------------------------------------------------------------------

vars_to_impute <- c("welfare", "y_nl", "y_rem", "y_pens", "y_cap", "y_sp", "y_renta", "y_durables", "y_gift", "y_food")

sim_noincome <- lapply(vars_to_impute, function(v) {
  subset(lfs.rec, flag6_income2 == 1, select = "hhid")
})
names(sim_noincome) <- vars_to_impute

# log_ymatch used for matching only — original ymatch kept for reference
X.mtc.noincome.D <- c("log_ymatch", "hh_size", "hhb_year")

for (sim in seq_len(nsim)) {
  set.seed(seed + sim)
  message("[No-income group - Opt D] Simulation ", sim, " of ", nsim)

  train <- blss.don |>
    filter(flag6_income2 == 1) |>
    group_by(district) |>
    sample_frac(n.a, replace = TRUE) |>
    ungroup()

  X_train <- model.matrix(mod_formula, data = train[, c("logwelfare", covariates)])
  dtrain  <- xgb.DMatrix(data = X_train, label = train$logwelfare)

  cv <- xgb.cv(params = best_params, data = dtrain,
               nrounds = 100, nfold = 5,
               early_stopping_rounds = 100, verbose = 0)
  best_nrounds <- cv$best_iteration
  if (is.null(best_nrounds)) best_nrounds <- nrow(cv$evaluation_log)

  model <- xgb.train(params = best_params, data = dtrain,
                     nrounds = best_nrounds, verbose = 0)

  X_don <- model.matrix(mod_formula,
                        data = blss.don[blss.don$flag6_income2 == 1,
                                        c("logwelfare", covariates)])

  rec_data <- lfs.rec[lfs.rec$flag6_income2 == 1, covariates] |>
    mutate(across(where(is.numeric), ~if_else(is.na(.), median(., na.rm = TRUE), .))) |>
    mutate(logwelfare = 0)
  X_rec <- model.matrix(mod_formula, data = rec_data[, c("logwelfare", covariates)])

  # Align columns to donor matrix — handles factor levels absent in receiver
  missing_cols <- setdiff(colnames(X_don), colnames(X_rec))
  for (mc in missing_cols) X_rec <- cbind(X_rec, setNames(data.frame(rep(0, nrow(X_rec))), mc))
  X_rec <- X_rec[, colnames(X_don), drop = FALSE]

  pred_don <- exp(predict(model, xgb.DMatrix(X_don)))
  pred_rec <- exp(predict(model, xgb.DMatrix(X_rec)))

  # Clip receiver log_ymatch to donor support before matching
  don_range <- range(log(pred_don + 1), na.rm = TRUE)

  don_pred <- blss.don[blss.don$flag6_income2 == 1, ] |>
    mutate(
      ymatch     = pred_don,
      log_ymatch = log(pred_don + 1)
    ) |>
    as.data.frame()

  rec_pred <- lfs.rec[lfs.rec$flag6_income2 == 1, ] |>
    mutate(
      ymatch     = pred_rec,
      log_ymatch = pmax(pmin(log(pred_rec + 1), don_range[2]), don_range[1])
    ) |>
    as.data.frame()

  group.v <- if (min(table(don_pred$district, don_pred$urban)) > 1) {
    c("district", "urban")
  } else {
    #c("district")
    c("urban")
  }

  rnd <- RANDwNND.hotdeck(
    data.rec   = rec_pred,
    data.don   = don_pred,
    match.vars = X.mtc.noincome.D,
    don.class  = group.v,
    dist.fun   = dist.fun.noincome,
    cut.don    = "min"
  )

  fused <- create.fused(
    data.rec = rec_pred,
    data.don = don_pred,
    mtc.ids  = rnd$mtc.ids,
    z.vars   = don.vars.noincome
  ) |>
    mutate(
      y_nl       = r_nlabor_c    * welfare,
      y_rem      = r_rem_c       * welfare,
      y_pens     = r_pens_c      * welfare,
      y_cap      = r_cap_c       * welfare,
      y_sp       = r_sp_c        * welfare,
      y_renta    = r_renta_c     * welfare,
      y_durables = r_durables_c  * welfare,
      y_gift     = r_gift_c      * welfare,
      y_food     = r_food_c
    )

  for (v in vars_to_impute) {
    col <- fused[, c("hhid", v)]
    names(col)[2] <- paste0(v, "_", sim)
    sim_noincome[[v]] <- merge(sim_noincome[[v]], col, by = "hhid")
  }

  rm(train, X_train, dtrain, cv, model, X_don, X_rec,
     pred_don, pred_rec, don_pred, rec_pred, rnd, fused)
}

# Aggregate per-household across simulations using agg.fun (set in 00_main.R)
lfs.imp.1 <- lfs.rec[lfs.rec$flag6_income2 == 1, ]

for (v in vars_to_impute) {
  mat <- sim_noincome[[v]][, -1]
  medians <- data.frame(
    hhid  = sim_noincome[[v]]$hhid,
    value = apply(as.matrix(mat), 1, agg.fun, na.rm = TRUE)
  )
  names(medians)[2] <- v
  lfs.imp.1 <- merge(lfs.imp.1, medians, by = "hhid", all.x = TRUE)
}

lfs.imp.1 <- lfs.imp.1 |>
  mutate(
    welfare    = welfare    * na_growth,
    y_nl       = y_nl       * na_growth,
    y_rem      = y_rem      * na_growth,
    y_pens     = y_pens     * na_growth,
    y_cap      = y_cap      * na_growth,
    y_sp       = y_sp       * na_growth,
    y_renta    = y_renta    * na_growth,
    y_durables = y_durables * na_growth,
    y_gift     = y_gift     * na_growth,
    y_food     = y_food                ,
    logwelfare = log(welfare)
  )

rm(sim_noincome, tuning_results, best_row, best_params,
   base_params, param_grid, mod_formula)