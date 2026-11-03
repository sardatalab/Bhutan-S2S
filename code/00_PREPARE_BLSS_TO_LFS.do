/*
00_prepare.do

Ivan Gachet
Created on : Mar 11, 2026
Last update: Mar 11, 2026

*/


*===============================================================================
* 1. INITIAL SETTINGS
*===============================================================================
** 1. Set path 
cd "D:\Dropbox\world bank\FY 2025-26\CEQ\Buthan\survey_to_survey\data"



*===============================================================================
* 2. ADJUST PER CAPITA LABOUR INCOMES BLSS 2022 TO LFS 2022
*===============================================================================
** 1. Run code
do "../code/aux_BLSS_LFSIncome_2022_adj.do"

keep if survey == 1
keep hhid  labor_pc_def_adj  
 
tempfile aux 
save "`aux'" 


*===============================================================================
* 2. PREPARE DATA BLSS 2022
*===============================================================================
** 1. BLSS for imputation
{
use "..\data\raw\BTN_2022_BLSS_v02_M_v04_A_s2s_BLSS_to_QLFS.dta", clear
	merge 1:1 hhid using  "`aux'" 
	drop _merge

	
	
** 2. Create groups
do "../code/aux_regions.do"

** 3. Outcomes
** => Non-labour incomes
egen nlaborinc_def  = rsum(income_12_def income_13_def income_14_def income_15_def /*
	*/  income_16_def income_17_def income_19_def income_20_def income_96_def           /*
	*/ renta_def durables_def gift_def)

replace nlaborinc_def = nlaborinc_def/12

gen nlabor_pc_def = nlaborinc_def/hh_size

* By component
** => Remittances
gen rem_def = income_12_def/12
gen rem_pc_def = rem_def  / hh_size

* => Pensions
gen pens_def_def = income_13_def / 12
gen pens_pc_def = pens_def  / hh_size

** => Capital
egen cap_def   = rsum(income_14_def income_19_def)
replace cap_def  = cap_def  / 12
gen cap_pc_def = cap_def  / hh_size

** => Social protection
egen sp_def  = rsum(income_16_def income_20_def)
replace sp_def = sp_def  / 12
gen sp_pc_def = sp_def /hh_size

** =>Imputed rent, rurables and gifts
local out = "renta durables gift"
foreach x of local out {
	replace `x'_def = `x'_def  / 12
	gen `x'_pc_def = `x'_def /hh_size
}

** => Other non-labour income
egen other_def   = rsum(income_15_def  income_17_def  income_96_def )
replace other_def  = other_def  /12
gen other_pc_def  = other_def   / hh_size

** => Check
egen aux = rsum(rem_pc_def  pens_pc_def cap_pc_def sp_pc_def renta_pc_def durables_pc_def gift_pc_def other_pc_def)
gen check = nlabor_pc_def - aux
sum check
sum check if check == 0
sum check if check != 0


drop income_12* income_13* income_14* income_15* income_16* income_17* income_19* /*
	*/ income_20* income_96* aux* check* income_1 income_2 income_3 income_4 income_5 /*
	*/ income_6 income_7 income_8 income_9 income_10 income_11 income_18 decile_national


** => Ratios
*gen r_cons = consumption_pc/ labor_pc_def
gen r_cons = consumption_pc/ labor_pc_def_adj

*gen food_pc_def = consumption_pc*share_food
gen r_food 	= share_food
gen r_food_c = share_food
drop share_food

*local out = "nlabor rem pens cap sp renta durables gift other food"
local out = "nlabor rem pens cap sp renta durables gift other"
foreach x of local out {
	gen r_`x' = `x'_pc_def / labor_pc_def
	gen r_`x'_c = `x'_pc_def / consumption_pc	
}

** => Drop variables
drop labor_pc_def
rename labor_pc_def_adj labor_pc_def

** => Variables
rename urb urban

gen flag6_income2 = labor_pc_def==0

rename consumption_pc welfare

gen hhb_year = 2022-hh_head_age + 3
gen hh_head_age_sq= hh_head_age^2


** => Save data
save "../data/raw/clean_BLSS_2022.dta ", replace 
}

*===============================================================================
* 2. PREPARE DATA QLFS 2023-2025
*===============================================================================

forvalues year = 2025/ 2025 {

** => Open data
	use "..\data\raw/BTN_`year'_QLFS_v01_M_v01_A_s2s_LFS_to_QLFS.dta", clear

** 2. Create groups
do "../code/aux_regions.do"

** 3. Outcomes

** => Area	
	rename urb urban
** => HH year of birt
	gen hhb_year = 2025-hh_head_age
	gen hh_head_age_sq= hh_head_age^2

** => Labour income variables
	rename hh_labor_inc laborinc 
	rename hh_labor_inc_def laborinc_def 

	rename labor_income_pc labor_pc
	rename  labor_income_pc_def labor_pc_def

** => HH without labour income 	
	gen flag6_income2 = labor_pc_def==0

** => Rename variables
	rename flag3_spouse hh_without_spouse
	gen hhwt = wgt / hh_size

	gen share_hh_inc = flag5_income
	recode share_hh_inc (0=1) (1=0)

	cap gen quarter = .
	cap gen wgtq = .
** => Drop variables not used in the imputation
	drop str_dzongkhag flag1_depen flag2_sex hh_head_educ_mon hh_sp_educ_mon hh_head_ls_wrk /*
	*/hh_head_ls_u hh_head_ls_nlf hh_head_wrk_regpaid hh_head_wrk_caspaid hh_head_wrk_piepaid /*
	*/ hh_head_wrk_owno hh_head_wrk_owag hh_head_wrk_empl hh_head_wrk_fano /*
		*/ hh_head_wrk_faag flag4_labor hh_head_sect_1 hh_head_sect_2 hh_head_sect_3 /*
		*/ hh_head_sect_4 hh_head_sect_5 hh_head_sect_6 hh_head_sect_7 hh_head_sect_8 /*
		*/ hh_head_sect_9 hh_head_sect_10 hh_sh_ls_wrk hh_sh_wrk_regpaid hh_sh_wrk_caspaid /*
		*/ hh_sh_wrk_piepaid hh_sh_wrk_ownnona hh_sh_wrk_ownagri hh_sh_wrk_employer /*
		*/ hh_sh_wrk_famnona hh_sh_wrk_famagri hh_sh_sect_1 hh_sh_sect_2 hh_sh_sect_3 /*
		*/ hh_sh_sect_4 hh_sh_sect_5 hh_sh_sect_6 hh_sh_sect_7 hh_sh_sect_8 hh_sh_sect_9 /*
		*/ hh_sh_sect_10 shr_wage_1 shr_wage_2 shr_wage_3 shr_wage_4 shr_wage_5 shr_wage_6 /*
		*/ shr_wage_act1 shr_wage_act2 shr_wage_act3 shr_wage_act4 shr_wage_act5 shr_wage_act6 /*
		*/ shr_wage_act7 shr_wage_act8 shr_wage_act9 shr_wage_act10 wgtq strata dcode flag5_income /*
		*/ decile_national
		
	order quarter hhid year hhwt wgt  

** => Save clean data for imputation	
	save "../data/raw/clean_LFS_`year'.dta ", replace 
}

*===============================================================================
* 2. PREPARE DATA LFS 2018-2022
*===============================================================================
forvalues year = 2022/ 2022 {

** => Open data
	use "..\data\raw/BTN_`year'_LFS_v01_M_v01_A_s2s_LFS_to_LFS.dta", clear

** 2. Create groups
do "../code/aux_regions.do"

** 3. Outcomes
** => Area	
	rename urb urban

** => HH year of birth	
	gen hhb_year = 2025-hh_head_age
	gen hh_head_age_sq= hh_head_age^2

** => Labour income variables
	rename hh_labor_inc laborinc 
	rename hh_labor_inc_def laborinc_def 

	rename labor_income_pc labor_pc
	rename  labor_income_pc_def labor_pc_def

** => HH without labour income 	
	gen flag6_income2 = labor_pc_def==0

** => Rename variables
	rename flag3_spouse hh_without_spouse
	gen hhwt = wgt / hh_size

	gen share_hh_inc = flag5_income
	recode share_hh_inc (0=1) (1=0)

** => Drop variables not used in the imputation
drop str_dzongkhag flag1_depen flag2_sex hh_head_educ_mon hh_sp_educ_mon hh_head_ls_wrk /*
	*/hh_head_ls_u hh_head_ls_nlf hh_head_wrk_regpaid hh_head_wrk_caspaid hh_head_wrk_piepaid /*
	*/ hh_head_wrk_owno hh_head_wrk_owag hh_head_wrk_empl hh_head_wrk_fano /*
		*/ hh_head_wrk_faag flag4_labor hh_head_sect_1 hh_head_sect_2 hh_head_sect_3 /*
		*/ hh_head_sect_4 hh_head_sect_5 hh_head_sect_6 hh_head_sect_7 hh_head_sect_8 /*
		*/ hh_head_sect_9 hh_head_sect_10 hh_sh_ls_wrk hh_sh_wrk_regpaid hh_sh_wrk_caspaid /*
		*/ hh_sh_wrk_piepaid hh_sh_wrk_ownnona hh_sh_wrk_ownagri hh_sh_wrk_employer /*
		*/ hh_sh_wrk_famnona hh_sh_wrk_famagri hh_sh_sect_1 hh_sh_sect_2 hh_sh_sect_3 /*
		*/ hh_sh_sect_4 hh_sh_sect_5 hh_sh_sect_6 hh_sh_sect_7 hh_sh_sect_8 hh_sh_sect_9 /*
		*/ hh_sh_sect_10 shr_wage_1 shr_wage_2 shr_wage_3 shr_wage_4 shr_wage_5 shr_wage_6 /*
		*/ shr_wage_act1 shr_wage_act2 shr_wage_act3 shr_wage_act4 shr_wage_act5 shr_wage_act6 /*
		*/ shr_wage_act7 shr_wage_act8 shr_wage_act9 shr_wage_act10  strata  flag5_income decile_national
		
	order  hhid year hhwt wgt 

** => Save clean data for imputation	
	save "../data/raw/clean_LFS_`year'.dta ", replace 
}
