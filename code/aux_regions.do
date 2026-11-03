/*
aux_regions.do
*/

*===============================================================================
* LOCATION GROUPS
*===============================================================================
** 1. dzongkhag
gen district = .
forvalues i = 1/20 {
	replace district = `i' if dzongkhag_`i'
	drop dzongkhag_`i'
}
** 2. Region groups
** => Group 1
/*
gen group_1 = .
	replace group_1 = 1 if district == 14
	replace group_1 = 2 if inlist(district, 2,5,8,12)
	replace group_1 = 3 if inlist(district, 3,4,10,18,19)
	replace group_1 = 4 if inlist(district, 1,13,17,20)
	replace group_1 = 5 if inlist(district, 6,7,9,11,15,16)
	
	drop district
	rename group_1 district
	*rename group_1 region
*/
** => Group 2
/*
gen group_2 = .
	replace group_2 = 1 if inlist(district, 2,5,8,12,14)
	replace group_2 = 2 if inlist(district, 3,4,10,18,19)
	replace group_2 = 3 if inlist(district, 1,13,17,20)
	replace group_2 = 4 if inlist(district, 6,7,9,11,15,16)
	
	drop district
	rename group_2 district
	*rename group_2 region
*/
** => Group 3
/*
*Best
gen group_3 = .
	replace group_3 = 1 if district == 2
	replace group_3 = 2 if district == 14
	replace group_3 = 3 if district == 13
	replace group_3 = 4 if district == 11
	replace group_3 = 5 if inlist(district, 5,8,12)
	replace group_3 = 6 if inlist(district, 3,4,10,18,19)
	replace group_3 = 7 if inlist(district, 1,17,20)
	replace group_3 = 8 if inlist(district, 6,7,9,15,16)

	drop district
	rename group_3 district
	*rename group_3 region	
*/
** => Group 4
/*
gen group_4 = .
	replace group_4 = 1 if district == 2
	replace group_4 = 2 if district == 14
	replace group_4 = 3 if inlist(district, 5,8,12)
	replace group_4 = 4 if inlist(district, 3,4,10,18,19)
	replace group_4 = 5 if inlist(district, 1,13,17,20)
	replace group_4 = 6 if inlist(district, 6,7,9,11,15,16)

	drop district
	rename group_4 district
	*rename group_4 region
*/	
** => Group 5
/*
gen group_5 = .
	replace group_5 = 1 if district == 2
	replace group_5 = 2 if district == 14
	replace group_5 = 3 if inlist(district, 5,8,12)
	replace group_5 = 4 if inlist(district, 3,4,10,18,19)
	replace group_5 = 5 if inlist(district, 1,13,17,20)
	replace group_5 = 7 if inlist(district, 6,7,9,11,15,16)
	
	drop district
	rename group_5 district
	*rename group_5 region
*/
** => Group 6
/*
gen group_6 = .
	replace group_6 = 1 if district == 2
	replace group_6 = 2 if district == 14
	replace group_6 = 3 if inlist(district, 5,8,12)
	replace group_6 = 4 if inlist(district, 3,4,10,18,19)
	replace group_6 = 5 if inlist(district, 1,13,17,20)
	replace group_6 = 6 if inlist(district, 6,7,9,11,15,16)
	
	drop district
	rename group_6 district
	*rename group_6 region
*/	
** => Group 7
/*
gen group_7 = .
	replace group_7 = 1 if district == 2
	replace group_7 = 2 if district == 14
	replace group_7 = 3 if inlist(district, 5,8,12)
	replace group_7 = 4 if inlist(district, 3,4,10,18,19)
	replace group_7 = 5 if inlist(district, 1,13,17,20)
	replace group_7 = 6 if inlist(district, 6,7,9,11,15,16)
	replace group_7 = 3 if group_7 == 6

	drop district
	rename group_7 district
	*rename group_7 region
*/


** => Group 9
* Same as group 3, but with Zhemgang as a separate group.
gen group_8 = .
	replace group_8 = 1 if district == 2
	replace group_8 = 2 if district == 14
	replace group_8 = 3 if district == 13
	replace group_8 = 4 if district == 11
	replace group_8 = 5 if inlist(district, 5,8,12)
	replace group_8 = 6 if inlist(district, 3,4,10,18,19)
	replace group_8 = 7 if inlist(district, 1,17,20)
	replace group_8 = 8 if inlist(district, 6,7,9,15,16)
	replace group_8 = 9 if  district == 20
	
	drop district
	rename group_8 district
	*rename group_8 region	

** => Labels

/*
label define district 1 "Bumthang" 2 "Chhukha" 3 "Dagana" 4 "Gasa" 5 "Haa" 6 "Lhuentse" /*
	*/ 7 "Monggar" 8 "Paro" 9 "Pema Gatshel" 10 "Punakha" 11 "Samdrup Jongkhar" 12 "Samtse" /*
	*/ 13 "Sarpang" 14 "Thimphu" 15 "Trashigang" 16 "Trashi Yangtse" 17 "Trongsa" 18 "Tsirang" /*
	*/ 19 "Wangdue Phodrang" 20 "Zhemgang", modify
		label values district district
*/


*===============================================================================
* QUANTALIES
*===============================================================================
*gen hhQ = decile_national
*recode hhQ (1 2= 1) (3 4=2) (5 6= 3) (7 8 =4) (9 10 = 5)