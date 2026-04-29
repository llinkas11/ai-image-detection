* Step 06: recode 16 string variables to numeric with value labels.
*
* The pattern repeated for every recoded variable:
*   rename old to placeholder, gen byte new with replace, drop placeholder.
* This avoids dataset-wide encode that would auto-assign label codes in
* alphabetical order (which is rarely the order we want).

clear all
set more off
use "AI_DetectionV3_lite.dta", clear


* ---------------------------------------------------------------------------
* Binary 0/1 variables
* ---------------------------------------------------------------------------
foreach v of varlist disability intl_student intl_faculty ai_course {
    rename `v' _raw
    gen byte `v' = .
    replace `v' = 0 if _raw == "No"
    replace `v' = 1 if _raw == "Yes"
    drop _raw
}

label define yn_lbl 0 "No" 1 "Yes", replace
foreach v of varlist disability intl_student intl_faculty ai_course {
    label values `v' yn_lbl
}


* ---------------------------------------------------------------------------
* Ordinal Likert and ordinal-bin variables
* ---------------------------------------------------------------------------

* detect_easy: 1=Strongly disagree .. 5=Strongly agree
rename detect_easy _raw
gen byte detect_easy = .
replace detect_easy = 1 if _raw == "Strongly disagree"
replace detect_easy = 2 if _raw == "Disagree"
replace detect_easy = 3 if _raw == "Neither agree nor disagree"
replace detect_easy = 4 if _raw == "Agree"
replace detect_easy = 5 if _raw == "Strongly agree"
drop _raw
label define agree5_lbl 1 "Strongly disagree" 2 "Disagree" ///
    3 "Neither" 4 "Agree" 5 "Strongly agree", replace
label values detect_easy agree5_lbl

* ai_literacy: same 5-point Likert
rename ai_literacy _raw
gen byte ai_literacy = .
replace ai_literacy = 1 if _raw == "Not at all literate"
replace ai_literacy = 2 if _raw == "Slightly literate"
replace ai_literacy = 3 if _raw == "Somewhat literate"
replace ai_literacy = 4 if _raw == "Very literate"
replace ai_literacy = 5 if _raw == "Extremely literate"
drop _raw
label define lit5_lbl 1 "Not at all" 2 "Slightly" 3 "Somewhat" ///
    4 "Very" 5 "Extremely", replace
label values ai_literacy lit5_lbl

* ai_familiarity: 1=Not at all .. 5=Extremely familiar
rename ai_familiarity _raw
gen byte ai_familiarity = .
replace ai_familiarity = 1 if _raw == "Not at all familiar"
replace ai_familiarity = 2 if _raw == "Slightly familiar"
replace ai_familiarity = 3 if _raw == "Somewhat familiar (I understand the basics)"
replace ai_familiarity = 4 if _raw == "Very familiar"
replace ai_familiarity = 5 if _raw == "Extremely familiar"
drop _raw
label values ai_familiarity lit5_lbl

* ai_use_time: hours-per-week buckets
rename ai_use_time _raw
gen byte ai_use_time = .
replace ai_use_time = 0 if _raw == "I don't use generative AI tools"
replace ai_use_time = 1 if _raw == "Less than 1 hour"
replace ai_use_time = 2 if _raw == "1-2 hours"
replace ai_use_time = 3 if _raw == "2-4 hours"
replace ai_use_time = 4 if _raw == "4-8 hours"
replace ai_use_time = 5 if _raw == "8+ hours"
drop _raw
label define hours_lbl 0 "None" 1 "<1h" 2 "1-2h" 3 "2-4h" ///
    4 "4-8h" 5 "8+h", replace
label values ai_use_time hours_lbl

* social_media_time: same buckets
rename social_media_time _raw
gen byte social_media_time = .
replace social_media_time = 0 if _raw == "Less than 1 hour"
replace social_media_time = 1 if _raw == "1-2 hours"
replace social_media_time = 2 if _raw == "2-4 hours"
replace social_media_time = 3 if _raw == "4-8 hours"
replace social_media_time = 4 if _raw == "8+ hours"
drop _raw
label define sm_lbl 0 "<1h" 1 "1-2h" 2 "2-4h" 3 "4-8h" 4 "8+h", replace
label values social_media_time sm_lbl


* ---------------------------------------------------------------------------
* Nominal categorical variables
* ---------------------------------------------------------------------------

* gender: 4 levels (collapsed to 3 in the analysis pipeline)
rename gender _raw
gen byte gender = .
replace gender = 1 if _raw == "Man"
replace gender = 2 if _raw == "Woman"
replace gender = 3 if _raw == "Non-binary / Third gender"
replace gender = 4 if _raw == "Prefer not to say"
drop _raw
label define gender_lbl 1 "Man" 2 "Woman" 3 "Non-binary / Third gender" ///
    4 "Prefer not to say", replace
label values gender gender_lbl

* race: 7 levels (codes 6 and 7 collapsed to 8 = Other in analysis)
rename race _raw
gen byte race = .
replace race = 1 if _raw == "White"
replace race = 2 if _raw == "Asian"
replace race = 3 if _raw == "Black or African American"
replace race = 4 if _raw == "Hispanic or Latino"
replace race = 5 if _raw == "Two or more races"
replace race = 6 if _raw == "International"
replace race = 7 if _raw == "Race/ethnicity unknown"
drop _raw
label define race_lbl 1 "White" 2 "Asian" 3 "Black or African American" ///
    4 "Hispanic or Latino" 5 "Two or more races" 6 "International" ///
    7 "Race/ethnicity unknown", replace
label values race race_lbl

* affiliation: 5 levels
rename affiliation _raw
gen byte affiliation = .
replace affiliation = 1 if _raw == "Class of 2026 (Senior)"
replace affiliation = 2 if _raw == "Class of 2027 (Junior)"
replace affiliation = 3 if _raw == "Class of 2028 (Sophomore)"
replace affiliation = 4 if _raw == "Class of 2029 (First-year)"
replace affiliation = 5 if _raw == "Faculty/Staff"
drop _raw
label define affil_lbl 1 "Class of 2026" 2 "Class of 2027" ///
    3 "Class of 2028" 4 "Class of 2029" 5 "Faculty/Staff", replace
label values affiliation affil_lbl

* device_type: 3 levels
rename device_type _raw
gen byte device_type = .
replace device_type = 1 if _raw == "Laptop"
replace device_type = 2 if _raw == "Mobile phone"
replace device_type = 3 if _raw == "Other"
drop _raw
label define dev_lbl 1 "Laptop" 2 "Mobile phone" 3 "Other", replace
label values device_type dev_lbl


* ---------------------------------------------------------------------------
* q1..q10: TP/TN/FP/FN -> 1/2/3/4
* ---------------------------------------------------------------------------
label define outcome_lbl 1 "TP" 2 "TN" 3 "FP" 4 "FN", replace
forvalues i = 1/10 {
    rename q`i' _raw
    gen byte q`i' = .
    replace q`i' = 1 if _raw == "TP"
    replace q`i' = 2 if _raw == "TN"
    replace q`i' = 3 if _raw == "FP"
    replace q`i' = 4 if _raw == "FN"
    drop _raw
    label values q`i' outcome_lbl
}


* ---------------------------------------------------------------------------
* Variable labels for documentation
* ---------------------------------------------------------------------------
label variable detect_easy        "AI detection was easy (1=SD, 5=SA)"
label variable ai_literacy        "Self-rated AI literacy (1-5)"
label variable ai_familiarity     "Self-rated AI familiarity (1-5)"
label variable ai_use_time        "Weekly AI use, hours (0=none, 5=8+h)"
label variable social_media_time  "Weekly social media use, hours"
label variable gender             "Gender identity"
label variable race               "Race / ethnicity"
label variable affiliation        "Bowdoin affiliation"
label variable device_type        "Device used during survey"
label variable disability         "Self-disclosed disability"
label variable intl_student       "International student flag"
label variable intl_faculty       "International faculty flag"
label variable ai_course          "Took an AI course at Bowdoin"
label variable score_total        "Detection score (Qualtrics native)"
label variable calc_score         "Detection score (Python verified)"
label variable avg_resp_time      "Mean per-image response time (sec)"

save "AI_DetectionV3_lite.dta", replace
display _newline "recoded `c(k)' variables, `c(N)' observations"
