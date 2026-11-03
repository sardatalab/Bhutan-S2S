# Combine imputed subgroups, compute poverty indicators, save final dataset.

lfs.imp <- bind_rows(lfs.imp.0, lfs.imp.1) |>
  mutate(
    # Convert monthly per-capita welfare to daily 2017 PPP USD
    welfare_ppp = welfare * (12 / 365) / cpi21 / icp21,
    pov30  = as.integer(welfare_ppp < pov_line_low),
    pov42  = as.integer(welfare_ppp < pov_line_mid),
    pov83  = as.integer(welfare_ppp < pov_line_high),
    povnpl = as.integer(welfare < npl)
  )

write_dta(lfs.imp, file.path(datapath, "processed", out_filename))
