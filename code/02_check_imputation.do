/*
00_check_gini.do

Ivan Gachet
Created on : Mar 11, 2026
Last update: Mar 11, 2026

*/


*===============================================================================
* 1. INITIAL SETTINGS
*===============================================================================
** 1. Set path 
cd "D:\Dropbox\world bank\FY 2025-26\CEQ\Buthan\survey_to_survey\data"

** 2. Run ados
do "..\code\gini.do"

*===============================================================================
* 2. PREPARE DATA
*===============================================================================
** 1. Append Data
use "..\data\processed\imputed_BLSS_2022_to_LFS_2018_.dta", clear

append using "..\data\processed\imputed_BLSS_2022_to_LFS_2019_.dta" /*
	*/ "..\data\processed\imputed_BLSS_2022_to_LFS_2020_.dta"/*
	*/ "..\data\processed\imputed_BLSS_2022_to_LFS_2021_.dta"/*
	*/ "..\data\processed\imputed_BLSS_2022_to_LFS_2022_Mahalanobis_Adj.dta"/*
	*/ "..\data\processed\imputed_BLSS_2022_to_LFS_2023_.dta"/*
	*/ "..\data\processed\imputed_BLSS_2022_to_LFS_2024_.dta"/*
	*/ "..\data\processed\imputed_BLSS_2022_to_LFS_2025_.dta"

** 2. Rename non-labour income variables
	rename  y_nl nlabor_pc_def 
	rename y_rem rem_pc_def    
	rename y_pens pens_pc_def  
	rename y_cap cap_pc_def   
	rename y_sp sp_pc_def 

egen aux  = rsum(rem_pc_def pens_pc_def cap_pc_def sp_pc_def)
	replace aux= aux*-1
egen other_pc_def  = rsum(nlabor_pc_def aux)
	replace other_pc_def = 0 if other_pc_def <0
	
** 3. Relevant variables 
keep hhid year welfare nlabor_pc_def rem_pc_def pens_pc_def cap_pc_def /*
	*/ sp_pc_def other_pc_def labor_pc_def

label var labor_pc_def		"Per capita labour income spatially deflated"
label var	welfare 				"Per capita consumption spatially deflated" 
label var	nlabor_pc_def  "Per capita non-labour income spatially deflated" 
label var	rem_pc_def  		"Per capita remittances spatially deflated" 
label var	pens_pc_def  	"Per capita pensions spatially deflated" 
label var	cap_pc_def  		"Per capita capital spatially deflated"
label var	sp_pc_def  		"Per capita social programs  spatially deflated" 
label var	other_pc_def  	"Per capita other non-labour spatially deflated"
	
*===============================================================================
* 3. SAVE DATA
*===============================================================================
** 1. Save
save "..\data\processed\imputed_BLSS_to_LFS_2018_2025.dta", replace 


