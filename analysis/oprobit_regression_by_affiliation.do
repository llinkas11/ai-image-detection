* Faculty-only and Student-only subsample regressions.
* Assumes oprobit-regression.do has already been run in the current Stata
* session -- data is cleaned, variables recoded, over_25 / ln_resp_time /
* collapsed gender + race already in memory. This file subsets via the
* `if` qualifier so the estimation sample is recoverable via e(sample)
* (needed for post-estimation margins / predict).

* FACULTY/STAFF  (over_25 == 1)
count if over_25 == 1
display "Faculty/Staff n: " r(N)

oprobit score i.gender i.race if over_25 == 1, vce(robust)
estimates store mf0

oprobit score i.device_type i.gender i.race if over_25 == 1, vce(robust)
estimates store mf1b

oprobit score i.device_type c.ai_use_time i.gender i.race if over_25 == 1, vce(robust)
estimates store mf3a

oprobit score i.device_type c.ai_familiarity i.gender i.race if over_25 == 1, vce(robust)
estimates store mf3b

oprobit score i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time if over_25 == 1, vce(robust)
estimates store mf3c

oprobit score i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time c.social_media_time if over_25 == 1, vce(robust)
estimates store mf4

oprobit score i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time c.social_media_time c.ln_resp_time if over_25 == 1, vce(robust)
estimates store mf5

estimates stats mf0 mf1b mf3a mf3b mf3c mf4 mf5

* STUDENTS  (over_25 == 0).  Keeps i.affiliation so class-year effects show.
count if over_25 == 0
display "Student n: " r(N)
tab affiliation if over_25 == 0

oprobit score i.affiliation i.gender i.race if over_25 == 0, vce(robust)
estimates store ms0

oprobit score i.affiliation i.device_type i.gender i.race if over_25 == 0, vce(robust)
estimates store ms1b

oprobit score i.affiliation i.device_type c.ai_use_time i.gender i.race if over_25 == 0, vce(robust)
estimates store ms3a

oprobit score i.affiliation i.device_type c.ai_familiarity i.gender i.race if over_25 == 0, vce(robust)
estimates store ms3b

oprobit score i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time if over_25 == 0, vce(robust)
estimates store ms3c

oprobit score i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time c.social_media_time if over_25 == 0, vce(robust)
estimates store ms4

oprobit score i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time c.social_media_time c.ln_resp_time if over_25 == 0, vce(robust)
estimates store ms5

estimates stats ms0 ms1b ms3a ms3b ms3c ms4 ms5
