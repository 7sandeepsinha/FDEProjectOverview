SELECT COUNT(*) FROM support_cases sc;

SELECT COUNT(*) FROM orders;

SELECT COUNT(*) FROM orders
WHERE delivery_date IS NULL;

SELECT COUNT(*) FROM orders
WHERE delivery_date IS NOT NULL;

-- NULL means in a database - not zero, not blank text, just unknown
-- Since we cant compare NULL, we cant use = sign, we will say IS NULL

SELECT COUNT(*) FROM human_reviews 
WHERE triggered_rule_id IS NULL;


-- FIND THE NUMBER OF SUPPORT CASES WHERE review_status = 'PENDING' AND 
-- case_type = 'DELIVERY' OR case_type = 'BILLING'

SELECT COUNT(*) AS wrong_query_rows -- as is used for naming the columns [ custom column names]
FROM support_cases
WHERE review_status = 'PENDING' 
AND case_type = 'DELIVERY' 
OR case_type = 'BILLING';

-- The above query is not correct, as we have not mentioned the conditions priority properly


SELECT * FROM support_cases WHERE review_status = 'PENDING' 
AND ( case_type = 'DELIVERY' OR case_type = 'BILLING');

-- alternate to above query  --> IN makes the query shorter

SELECT * FROM support_cases WHERE review_status = 'PENDING' 
AND ( case_type IN ('DELIVERY', 'BILLING') );


SELECT COUNT(*) AS pending_delivery_billing_count 
FROM support_cases WHERE review_status = 'PENDING' 
AND ( case_type IN ('DELIVERY', 'BILLING') );

-- How many cases were reviewed by human 
SELECT COUNT(*) AS review_events FROM human_reviews; -- total number of times, human review happened

SELECT COUNT(DISTINCT case_id) AS reviewed_cases  
FROM human_reviews; -- unique case ids which were human reviewed

-- Try to find the count of cases for particular review status 

SELECT COUNT(DISTINCT case_id) AS reviewed_cases
FROM human_reviews WHERE decision = 'APPROVED'; -- unique case ids which were human reviewed and APPROVED

SELECT decision as Review_Outcome, COUNT(DISTINCT case_id) as Total_Cases
FROM human_reviews 
GROUP BY decision
ORDER BY COUNT(DISTINCT case_id) desc; -- default is asc, desc for descending


-- Trends in review timings - 

SELECT reviewer_role,
       COUNT(*) AS review_events,
       MIN(handling_minutes) AS fastest_minutes,
       MAX(handling_minutes) AS slowest_minutes,
       ROUND(AVG(handling_minutes), 2) AS average_minutes
FROM human_reviews
GROUP BY reviewer_role
ORDER BY average_minutes DESC, reviewer_role;

-- Who Handled the Single Slowest Review
SELECT review_id, case_id, reviewer_role, decision, handling_minutes
FROM human_reviews
ORDER BY handling_minutes DESC, review_id
LIMIT 10;



-- Preview Before You Touch Anything

-- UPDATE EXAMPLE 
#Check the row before updating
SELECT case_id, review_status
FROM support_cases
WHERE case_id = 'MCS-000506';

#update
UPDATE support_cases
SET review_status = 'PENDING'
WHERE case_id = 'MCS-000506';

#verify the update
SELECT case_id, review_status
FROM support_cases
WHERE case_id = 'MCS-000506';

-- DELETE EXAMPLE 
SELECT * FROM support_cases WHERE case_id = 'MCS-000507';

-- always make sure, delete has a WHERE query 
DELETE FROM support_cases WHERE case_id = 'MCS-000507';

DELETE FROM support_cases; -- delete the whole table 

-- In this accepted load, which issue types were routed to human review,
-- and which validation rule caused the route?

-- COUNT VIA ISSUE TYPE
SELECT issue_type, 
COUNT(*) AS issue_count 
FROM issue_records 
GROUP BY issue_type 
ORDER BY issue_count DESC, issue_type;

-- COUNT VIA VIOLATION RULE 
SELECT triggered_rule_id, COUNT(*) AS review_events
FROM human_reviews
WHERE triggered_rule_id IS NOT NULL
GROUP BY triggered_rule_id
ORDER BY review_events DESC, triggered_rule_id;






