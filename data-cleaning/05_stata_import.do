* Step 05: import the lite CSV into Stata, rename to snake_case,
* fix en-dashes in any string variables. Output: AI_DetectionV3_lite.dta.

clear all
set more off

import delimited "AI_DetectionV3_lite.csv", varnames(1) encoding(utf-8) clear

* Per-question outcomes and confidence sliders renamed in a forvalues loop.
forvalues i = 1/10 {
    capture rename q`i'      q`i'_old
    capture rename q`i'_old  q`i'
    capture rename q`i'conf  q`i'_conf
}

* Hand-rename the rest. Stata's import auto-shortens long headers
* (e.g. "AI detection was easy" becomes aidetectionwaseasy); we shorten
* further for readability.
capture rename startdate              start_date
capture rename enddate                end_date
capture rename duration               duration_sec
capture rename recordeddate           recorded_date
capture rename aidetectionwaseasy     detect_easy
capture rename ailiteracy             ai_literacy
capture rename aiusetime              ai_use_time
capture rename socialmediausetime     social_media_time
capture rename aifamiliarity          ai_familiarity
capture rename aicourseyn             ai_course
capture rename aiclassestaken         ai_classes
capture rename affiliation            affiliation
capture rename internationalstudent   intl_student
capture rename internationalfaculty   intl_faculty
capture rename age                    age
capture rename gender                 gender
capture rename race                   race
capture rename disability             disability
capture rename adhd                   adhd
capture rename devicetype             device_type
capture rename deviceother            device_other
capture rename imgcount               img_count
capture rename attncheck1             attn_check1
capture rename attnconf1              attn_conf1
capture rename attncheck2             attn_check2
capture rename attnconf2              attn_conf2
capture rename calculatedscore        calc_score
capture rename score                  score_total
capture rename avganswtime            avg_resp_time

* En-dash cleanup: some imported labels have Unicode en-dashes
* (e.g. "2 - 4 hours" came in as "2 [u2013] 4 hours"). Replace with ASCII hyphen.
* uchar(8211) is the Unicode codepoint for the en-dash (U+2013).
foreach v of varlist _all {
    capture confirm string variable `v'
    if !_rc {
        quietly replace `v' = usubinstr(`v', uchar(8211), "-", .)
    }
}

save "AI_DetectionV3_lite.dta", replace
display _newline "wrote AI_DetectionV3_lite.dta with `c(k)' variables and `c(N)' observations"
