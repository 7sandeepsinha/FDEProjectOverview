-- Section 5 | Run only this entire one-statement file in S AFTER file 04.
-- An access-denied error (typically 1142) IS THE EXPECTED SUCCESSFUL TEST.
-- Do not try this query through A; A is privileged and will not prove denial.
SELECT case_id,full_name,email,phone FROM meridian_retail.class11_case_profiles LIMIT 4;
