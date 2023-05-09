/*
Project: Mali Speed School
Objectives: Generate panel dataset with round 1 bl (2012), round 1 el (2014), round 2 (2016-17)
--------------------------------------------------------------------------------
Input do files:
	1. $user/Speed School/Analysis/do/filepaths.do

Input dta files:
	1. $raw/round1_bl.dta
	2. $raw/round1_el.dta
	3. $raw/round2.dta
	4. $raw/aggr_Battentes_homme_enf.dta
	5. $raw/aggr_Battentes_femme_enf.dta
	
Output dta files:
	1. $cleandta/round1_bl_childlevel.dta
	2. $cleandta/round1_el_childlevel.dta
	3. $cleandta/round2_childlevel.dta
	4. $cleandta/parent_aspirations.dta
	
	5. $cleandta/panel_childlevel_blelr2.dta  // This is the MAIN output. This do file was written to create this master panel dataset. 

--------------------------------------------------------------------------------

Notes:

	1. Round 1 baseline had no data for group F
	2. Group E is to be discarded in all rounds - not part of experiment
	3. Round 2 was only conducted in treatment villages i.e. Group A, B and C. No data for groups D or F. No parental aspirations variables. No socioemotional indicators for children.

Steps for creating panel dataset:

The thinking behind creating a panel dataset that incl data for Round 1 baseline, Round 1 endline and Round 2 is to use the age eligibility criteria in the Round 1 baseline (children of ages 8-12). Merge baseline age with subsequent rounds to include/exclude children from the analysis. That is, AD confirmed that children who are not in the baseline (and only in subsequent rounds) need not be included in the analysis since they never had the chance to be allocated to Speed School, which was determined using baseline data. The exception to this is Group F, which was only collected at Endline. 

The plan:
	1) Merge the baseline age variable into subsequent rounds datasets (r1 endline and r2)
	2) In these datasets, drop observations based on baseline age criteria (ages 8-12). Results in child-level dataset for each round.
	3) Append all 3
	4) For group F, since there is no baseline data, the availability of testing data at endline is used to identify children (since adults were not tested). It is possible that there are eligible children for whom testing data is simply missing, but these too will be excluded from the childlevel dataset. 
	5) Parental aspirations variable will need to be merged in from separate raw (but previously cleaned) files
	
	
The goal is to generate a panel dataset with round 1 bl (2012), round 1 el (2014), round 2 (2016-17), at the child-level. 

--------------------------------------------------------------------------------
	
Created on: Oct 22, 2020
Last updated: Dec 07, 2020
Creted by: Navishti Das
Updated by: Navishti Das
*/


********************************************************************************
* FILE PATHS *
********************************************************************************

dis "The user is: " c(username)

if c(username) == "Navishti" {
global user C:/Users/Navishti/Box Sync
}

if "$user" == "" {
display as error "Please update working directory to Box"
exit
}

do "$user/SpeedSchool_Navishti/Analysis/do/filepaths.do"

********************************************************************************

						******************************
						* Round 1 baseline: Sep 2012 *
						******************************

use "$raw/round1_bl", clear

	* keep only children 8-12 (eligible ages)
keep if age_bl>=8 & age_bl<=12

	* Treated var is kind of like group var
label define treat_group 0 "D" 1 "C" 2 "A/B"
label values treated treat_group

destring numvill, replace

save "$cleandta/round1_bl_childlevel.dta", replace // 4,363 obs



						*****************************
						* Round 1 endline: Jun 2014 *
						***************************** 

use "$raw/round1_el.dta", clear

	* Dropping a few observations that are blank and have bogus IDs
gen byte notnumericID = real(FPrimary)==.
drop if notnumericID == 1
drop notnumericID

drop if idp == . // 182 records dropped. Most have math scores, but not digit, raven, language

tempfile blel_merged
	* Merging in baseline age
	rename age age_el	
	merge 1:1 FPrimary idp using "$cleandta/round1_bl_childlevel.dta", keepusing(age_bl) // 3,378 _merge == 3
	keep if _merge == 3 // since we only retain children who present at baseline
	
		drop if group == "F" // to prevent duplicating few obs for group F that were collected in baseline, later when I append group F obs

save `blel_merged'

	* But this way, we lose Group F, because they were not included in baseline. Bringing them back. 

use "$raw/round1_el.dta", clear

keep if group == "F"
drop if 				///
	math_score == . & 	///
	lang_score == . & 	///
	ravenScore == . & 	///
	digit_score == .
	
 // For group F, since there is no baseline data, the availability of testing data is used to identify children (since adults were not tested). It is possible that there are children for whom testing data is simply missing.
 
 * count if age >= 10 & age <= 14 & math_score == . & lang_score == . & ravenScore == . & digit_score == . & group == "F"
 // 204 such cases. 

	* Now combining group F observations and the merged (and therefore verified to be children) observations for all other groups

append using `blel_merged'

save "$cleandta/round1_el_childlevel.dta", replace // 3,378 obs


						********************************
						* Round 2 (follow-up): 2016-17 *
						********************************
* Round 2 data was only collected for groups A, B and C (same as baseline)
						
use "$raw/round2.dta", clear

drop group idp
decode type, gen(group)
rename key_ind idp

	* Merging in baseline age
rename age age_r2
merge 1:1 FPrimary idp using "$cleandta/round1_bl_childlevel.dta", keepusing(age_bl) // 1,882 _merge == 3
keep if _merge == 3 // since we only retain children who present at baseline

save "$cleandta/round2_childlevel.dta", replace // 1,882 obs


								*********************
								* Append all rounds *
								*********************
								
use "$cleandta/round1_bl_childlevel.dta", clear
append using "$cleandta/round1_el_childlevel.dta", gen(endline)
append using "$cleandta/round2_childlevel.dta", gen(round2)

* Generating wave variable which indicates whether bl, el or r2 data
replace endline = 2 if round2 == 1
recode endline (0=1) (1=2) (2=3)
rename endline wave
label define wave 1 "Round 1 bl" 2 "Round 1 el" 3 "Round 2"
label values wave wave

drop _merge round2

								**********************
								* Clean and organize *
								**********************


order wave treated group, after(idp)
sort FPrimary idp wave

tostring idp, replace
egen unique_childid = concat(FPrimary idp)
destring unique_childid, replace
order unique_childid, after(idp)

* Filling in blanks in 'group' variable
capture ssc install stripolate
bysort unique_childid: stripolate group wave, gen(group_complete) groupwise

decode treated, gen(r1_group)
replace group_complete = r1_group if group_complete == "" & r1_group != ""
encode group_complete, gen(group_nomiss)
drop r1_group group_r2 group_complete treated group

rename group_nomiss group

* Filling in blanks in 'numvill' variable - R2 didn't enter village ID, but it's first few digits of FPrimary (hard to say how many because vill ID is not always constant digits)
bysort FPrimary: mipolate numvill wave, gen(numvill_complete) groupwise


* Removing children in Group E because that's not an actual treatment arm
drop if group == 6
 * Now reorganizing the label to be more intuitive
 recode group 	(2=12) /// mix of A and B
	(3=2) (4=3) (5=4) (7=5) 
				
 label define group_nomiss 1 "A" 2 "B" 12 "A/B" 3 "C" 4 "D" 5 "F", replace


* Organizing
order group, after(wave)
sort FPrimary idp wave

br FPrimary idp age attend group wave psych*_index* math_score lang_score digit_score ravenScore school_exp 

save "$cleandta/panel_childlevel_blelr2.dta", replace



					*****************************************
					* Adding aspiration vars from raw files *
					*****************************************

local parentsex "homme femme"

foreach x of local parentsex {
					
use "$raw/aggr_Battentes_`x'_enf.dta", clear

rename id_enfants idp

tostring idp, replace
egen unique_childid = concat(FPrimary idp) if idp != .
destring unique_childid, replace
order unique_childid, after(idp)

keep unique_childid *_non_primaire_gain *_primaire_gain *_non_secondaire_gain *_secondaire_gain *_non_prof_gain *_prof_gain

rename BSL_* *1
rename END_* *2

duplicates drop
duplicates tag unique_childid, gen(dup)
egen nmiss=rmiss(*)
drop if nmis == 12 & dup != 0 // dropping when all vars are blank

* DUPLICATES: In femme file, 27 child IDs (total 54 records) with duplicate IDs and where data is not exactly the same (so not an obvious drop) for femme file. 15 such child IDs (total 30 records) for homme file. 
	* Setting sort seed, so the same observation is always dropped even when do file is run multiple times
	* Sorting by no. of missing values, so we can retain observation with fewer missing values
	* When both duplicates have same number of missing values, dropping the second one (which will always be the same due to sortseed). 

set sortseed 1234
sort unique_childid nmiss
bysort unique_childid: drop if dup != 0 & _n != 1

reshape long non_primaire_gain primaire_gain non_secondaire_gain secondaire_gain non_prof_gain prof_gain, i(unique_childid) j(wave)

tempfile `x'_aspiration
save ``x'_aspiration'
}

use `homme_aspiration', clear
ds unique_childid wave, not
foreach var of varlist `r(varlist)' {
	rename `var' m_`var'
}
save `homme_aspiration', replace

use `femme_aspiration', clear
ds unique_childid wave, not
foreach var of varlist `r(varlist)' {
	rename `var' w_`var'
}

merge 1:1 unique_childid wave using `homme_aspiration'
drop _merge

* Renaming vars to shorten

ren 	w_non_primaire_gain 		w_nonprim
ren		w_primaire_gain 			w_prim
ren		w_non_secondaire_gain 		w_nonsec
ren		w_secondaire_gain 			w_sec
ren		w_non_prof_gain 			w_nonprof
ren 	w_prof_gain					w_prof

ren 	m_non_primaire_gain 		m_nonprim
ren		m_primaire_gain 			m_prim
ren		m_non_secondaire_gain 		m_nonsec
ren		m_secondaire_gain 			m_sec
ren		m_non_prof_gain 			m_nonprof
ren 	m_prof_gain					m_prof

save "$cleandta/parent_aspirations.dta", replace

*--------------------------------------

use "$cleandta/panel_childlevel_blelr2.dta", clear
drop w_* m_* 

merge 1:1 unique_childid wave using "$cleandta/parent_aspirations.dta"
drop _merge

save "$cleandta/panel_childlevel_blelr2.dta", replace
