/*
aux_BLSS_LFSIncome_2022_adj.do

This do-file adjust  BLSS labour incomes 

*/

*===============================================================================
* PREPARE DATA
*===============================================================================
** 1. Open  BLSS 2022
use "..\data\raw\BTN_2022_BLSS_v02_M_v04_A_s2s_BLSS_to_QLFS.dta", clear
	gen survey = 1

** 2. Appen 
append using  "..\data\raw/BTN_2022_LFS_v01_M_v01_A_s2s_LFS_to_LFS.dta"
    replace survey = 2 if survey == .
	replace labor_pc_def =  labor_income_pc_def if survey == 2
	
label define survey_lbl 1 "BLSS 2022" 2 "LFS 2022", replace
label values survey survey_lbl

* 2. log-transform
gen double income = ln(labor_pc_def)
label variable income "log labor_pc_def"

*===============================================================================
* 2. ADJUSTMENT
*===============================================================================
* 1. Weighted means and SDs by survey (stored as scalars, not variables)
qui sum income [iw=wgt] if survey == 1
gen mean1 = r(mean)
gen sd1   = r(sd)

qui sum income [iw=wgt] if survey == 2
gen mean2 = r(mean)
gen sd2   = r(sd)

/*
gen mean1 = .
gen sd1   = .
gen mean2 = .
gen sd2   = .

levelsof region, local(regions)
levelsof urban, local(urbans)

foreach r of local regions {
    foreach u of local urbans {
        * ---- Survey 1 moments ----
        quietly summarize income [iw=wgt] ///
            if survey==1 & region==`r' & urban==`u'

        local m1 = r(mean)
        local s1 = r(sd)
        * ---- Survey 2 moments ----
        quietly summarize income [iw=wgt] ///
            if survey==2 & region==`r' & urban==`u'

        local m2 = r(mean)
        local s2 = r(sd)

        * Store values
        replace mean1 = `m1' if region==`r' & urban==`u'
        replace sd1 = `s1' if region==`r' & urban==`u'
        replace mean2 = `m2' if region==`r' & urban==`u'
        replace sd2 = `s2' if region==`r' & urban==`u'
    }
}

assert sd1 > 0 & sd2 > 0
*/

* 2. Z-score rescaling of BLSS to LFS distribution (log space)
*    income_adj = ((income − μ_BLSS) / σ_BLSS) × σ_LFS + μ_LFS   for BLSS
*    income_adj = income                                            for LFS
*
*    After this: mean(income_adj|BLSS) = mean(income|LFS)
*                  sd(income_adj|BLSS) =   sd(income|LFS)
*---------------------------------------------------------------------------
gen double income_adj = income
replace income_adj = ( (income - mean1) / sd1 ) * sd2 + mean2 /*
	*/     if survey == 1 & !missing(income)

label variable income_adj "Adjusted log income (BLSS rescaled to LFS; LFS unchanged)"


* 3. Verify log-space adjustment
table var survey  [iw=wgt] , stat(mean income income_adj ) stat(sd income income_adj ) notot

tw    (kdensity income     if survey == 1 [aw=wgt], lc(red)   lp(solid)) /*
	*/ (kdensity income     if survey == 2 [aw=wgt], lc(blue)  lp(solid)) /*
	*/ (kdensity income_adj if survey == 1 [aw=wgt], lc(green) lp(dash)) /*
	*/ , legend(order(                                                                 /*
	*/ 1 "BLSS 2022 — original"                           /*
	*/ 2 "LFS  2022 — original"                             /*
	*/ 3 "BLSS 2022 — adjusted ") pos(6) rows(1))                        /*
	*/ title("Log per-capita income: original vs adjusted")      /*
	*/ xtitle("Log per capita labour income") ytitle("Density")                      /*
	*/ note("Z-score rescaling of BLSS to LFS mean and SD. Weights: aw.") 

	sum income income_adj   [iw=wgt] if survey ==2
	
 
 
cumul income if survey ==1, gen(base_blss) 
cumul income_adj if survey ==1, gen(adj_blss) 
cumul income if survey ==2, gen(base_lfs) 

tw    (line base_blss  income if survey == 1 [aw=wgt], lc(red)   lp(solid)) /*
	*/ (line base_lfs     income if survey == 2 [aw=wgt], lc(blue)  lp(solid)) /*
	*/ (line adj_blss 	income_adj if survey == 1 [aw=wgt], lc(green) lp(dash)) /*
	*/ , legend(order(                                                                 /*
	*/ 1 "BLSS 2022 — original"                           /*
	*/ 2 "LFS  2022 — original"                             /*
	*/ 3 "BLSS 2022 — adjusted ") pos(6) rows(1))                         /*
	*/ title("Log per-capita income: original vs adjusted")      /*
	*/ xtitle("Log per capita labour income") ytitle("Density")                      /*
	*/ note("Z-score rescaling of BLSS to LFS mean and SD. Weights: aw.") 



*---------------------------------------------------------------------------
* 5. Recover original values
*---------------------------------------------------------------------------	  
gen labor_pc_def_adj = exp(income_adj)
	replace labor_pc_def_adj = 0 if labor_pc_def == 0

	sum labor_pc_def labor_pc_def_adj  [iw=wgt] if survey ==2
	
	
	table survey [iw=wgt], stat(mean labor_pc_def labor_pc_def_adj)

table var survey  [iw=wgt] if labor_pc_def>0, stat(mean labor_pc_def labor_pc_def_adj ) stat(sd labor_pc_def labor_pc_def_adj ) notot

tw    (kdensity labor_pc_def     if survey == 1 [aw=wgt], lc(red)   lp(solid)) /*
	*/ (kdensity labor_pc_def     if survey == 2 [aw=wgt], lc(blue)  lp(solid)) /*
	*/ (kdensity labor_pc_def_adj if survey == 1 [aw=wgt], lc(green) lp(dash)) /*
	*/ , legend(order(                                                                 /*
	*/ 1 "BLSS 2022 — original"                           /*
	*/ 2 "LFS  2022 — original"                             /*
	*/ 3 "BLSS 2022 — adjusted "))                        /*
	*/ title("Per-capita income: original vs adjusted")      /*
	*/ xtitle("ln(labor_pc_def)") ytitle("Density")                      /*
	*/ note("Z-score rescaling of BLSS to LFS mean and SD. Weights: aw.") 

tw    (kdensity labor_pc_def     if survey == 1 [aw=wgt], lc(red)   lp(solid)) /*
	*/ (kdensity labor_pc_def     if survey == 2 [aw=wgt], lc(blue)  lp(solid)) /*
	*/ (kdensity labor_pc_def_adj if survey == 1 [aw=wgt], lc(green) lp(dash)) /*
	*/ if labor_pc_def < 200000, legend(order(                                                                 /*
	*/ 1 "BLSS 2022 — original"                           /*
	*/ 2 "LFS  2022 — original"                             /*
	*/ 3 "BLSS 2022 — adjusted "))                        /*
	*/ title("Per-capita income: original vs adjusted")      /*
	*/ xtitle("ln(labor_pc_def)") ytitle("Density")                      /*
	*/ note("Z-score rescaling of BLSS to LFS mean and SD. Weights: aw.") 

tw    (kdensity labor_pc_def     if survey == 2 [aw=wgt], lc(blue)  lp(solid)) /*
	*/ (kdensity labor_pc_def_adj if survey == 1 [aw=wgt], lc(green) lp(dash)) /*
	*/ if labor_pc_def < 200000, legend(order(                                                                 /*
	*/ 1 "LFS  2022 — original"                             /*
	*/ 2 "BLSS 2022 — adjusted "))                        /*
	*/ title("Per-capita income: original vs adjusted")      /*
	*/ xtitle("ln(labor_pc_def)") ytitle("Density")                      /*
	*/ note("Z-score rescaling of BLSS to LFS mean and SD. Weights: aw.") 
	
	
