# Produce summary tables and validation figures. All outputs saved to output/.

# ------------------------------------------------------------------------------
# Poverty and inequality summary table
# ------------------------------------------------------------------------------

lfs_plot <- lfs.imp |>
  filter(!is.na(welfare)) |>
  select(district, welfare, wgt) |>
  mutate(survey = "LFS",
         welfare = as.numeric(welfare),
         wgt     = as.numeric(wgt))

blss_plot <- blss.don |>
  select(district, welfare, wgt) |>
  mutate(survey = "BLSS",
         welfare = as.numeric(welfare),
         wgt     = as.numeric(wgt))

df <- bind_rows(lfs_plot, blss_plot) |>
  na.omit() |>
  mutate(
    welfare_ppp = welfare * (12 / 365) / cpi21 / icp21,
    pov30  = as.integer(welfare_ppp < pov_line_low),
    pov42  = as.integer(welfare_ppp < pov_line_mid),
    pov83  = as.integer(welfare_ppp < pov_line_high),
    povnpl = as.integer(welfare < npl)
  )

svydf <- svydesign(ids = ~1, data = df, weights = ~wgt)

poverty_rates <- as.data.frame(
  svyby(~pov30 + pov42 + pov83 + povnpl, ~survey,
        design = svydf, svymean, na.rm = TRUE, vartype = "ci")
)

svydf_convey <- convey_prep(svydf)

gini_blss <- svygini(~welfare, subset(svydf_convey, survey == "BLSS"), na.rm = TRUE)
gini_lfs  <- svygini(~welfare, subset(svydf_convey, survey == "LFS"),  na.rm = TRUE)

gini_table <- data.frame(
  survey    = c("BLSS", "LFS"),
  gini      = c(coef(gini_blss),       coef(gini_lfs)),
  gini_ci_l = c(confint(gini_blss)[1], confint(gini_lfs)[1]),
  gini_ci_u = c(confint(gini_blss)[2], confint(gini_lfs)[2])
)

poverty_summary <- merge(poverty_rates, gini_table, by = "survey")

print(poverty_summary)

write.csv(poverty_summary,
          file.path(outpath, paste0("poverty_summary_", file_label, ".csv")),
          row.names = FALSE)

# ------------------------------------------------------------------------------
# Figure: kernel density of log welfare by survey
# ------------------------------------------------------------------------------

# Poverty lines back-transformed to log local currency for annotation
pov_lines_log <- log(c(pov_line_low, pov_line_mid, pov_line_high) *
                       (365 / 12) * icp21 * cpi21)

fig_density <- ggplot(df, aes(x = log(welfare), weight = wgt, fill = survey)) +
  geom_density(alpha = 0.4, adjust = 1.5) +
  geom_vline(xintercept = pov_lines_log, linetype = "dashed", linewidth = 0.5) +
  labs(x = "Log consumption", y = "Density",
       title = paste0("Original and imputed log consumption: ", survey_label),
       fill = "Survey")

print(fig_density)
ggsave(file.path(outpath, paste0("fig_density_", file_label, ".pdf")),
       fig_density, width = 20, height = 14, units = "cm")

# ------------------------------------------------------------------------------
# Figure: ECDF of log welfare by survey
# ------------------------------------------------------------------------------

df_ecdf <- df |>
  arrange(log(welfare)) |>
  mutate(cum_weight   = cumsum(wgt),
         total_weight = sum(wgt),
         ecdf         = cum_weight / total_weight,
         .by = survey)

fig_ecdf <- ggplot(df_ecdf, aes(x = log(welfare), y = ecdf, color = survey)) +
  geom_step() +
  geom_vline(xintercept = pov_lines_log, linetype = "dashed", linewidth = 0.5) +
  annotate("text", x = pov_lines_log,
           y    = 0,
           label = paste0("$", c(pov_line_low, pov_line_mid, pov_line_high)),
           vjust = 1.5, size = 2.5) +
  labs(x = "Log consumption", y = "Cumulative share",
       title = paste0("ECDF of original and imputed log consumption: ", survey_label),
       color = "Survey")

print(fig_ecdf)
ggsave(file.path(outpath, paste0("fig_ecdf_", file_label, ".pdf")),
       fig_ecdf, width = 20, height = 14, units = "cm")
