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



----- 05/10 
SELECT COUNT(*) AS review_events FROM human_reviews;
-- Take the two cases we know best, MCS-501 and MCS-502, 
-- and put each case next to its reviews

SELECT sc.case_id, sc.review_status, hr.review_id, hr.decision
FROM support_cases sc
LEFT JOIN human_reviews hr
  ON hr.case_id = sc.case_id
WHERE sc.case_id IN ('MCS-501', 'MCS-502');
-- SQL Error [1052] [23000]: Column 'case_id' in field list is ambiguous

SELECT sc.case_id, sc.review_status, hr.review_id, hr.decision
FROM support_cases sc
LEFT JOIN human_reviews hr
  ON hr.case_id = sc.case_id
WHERE sc.case_id IN ('MCS-501', 'MCS-502');

-- Show me all 25,000 cases. Where a case has a review that names a
-- validation rule, attach that review

-- List all support cases, then attach human reviews whereever applicable, where 
-- some validation rule was triggered 

-- LEFT JOIN, with matching via caseId, and where clause saying triggered rule NOT NULL
 
SELECT COUNT(*) AS rows_returned
FROM support_cases sc
LEFT JOIN human_reviews hr
  ON hr.case_id = sc.case_id
WHERE hr.triggered_rule_id IS NOT NULL;
-- OUTPUT - 3564 

-- Creating a joined table, that contains 25000 rows, with the human reviews 
-- combined, post that filtering the rows which contain triggered rules


-- REQUIREMENT -> take those human review rows,
-- where triggered rules is NOT NULL, then do the LEFT JOIN.


SELECT COUNT(DISTINCT sc.case_id) AS cases_kept,
       COUNT(hr.review_id) AS rule_named_reviews
FROM support_cases AS sc
LEFT JOIN human_reviews AS hr
  ON hr.case_id = sc.case_id
  AND hr.triggered_rule_id IS NOT NULL;

--  the issue, the review, and the rule
-- Show me all 25,000 cases. Where a case has a review that names a
-- validation rule, attach that review and showcase the rule as well 

SELECT sc.case_id AS CaseId,
		hr.review_id as ReviewId,
		hr.triggered_rule_id as RuleId,
		vr.condition_text as Rule
FROM support_cases AS sc
LEFT JOIN human_reviews AS hr
  ON hr.case_id = sc.case_id
  AND hr.triggered_rule_id IS NOT NULL
INNER JOIN validation_rules vr 
 ON hr.triggered_rule_id = vr.rule_id ;


-- Which cases has nobody reviewed yet
SELECT sc.case_id, sc.customer_question, hr.review_id
FROM support_cases sc 
LEFT JOIN human_reviews hr 
ON sc.case_id  = hr.case_id
WHERE hr.review_id IS NULL;

SELECT COUNT(sc.case_id),COUNT(hr.review_id)
FROM support_cases sc 
LEFT JOIN human_reviews hr 
ON sc.case_id  = hr.case_id
WHERE hr.review_id IS NULL;


-- SUB QUERIES 
-- everything we can do with sub queries, can also be done via joins, 
-- sub queries make it easier to write and understand 

SELECT sc.case_id, sc.customer_question, hr.review_id
FROM support_cases sc 
LEFT JOIN human_reviews hr 
ON sc.case_id  = hr.case_id
WHERE hr.review_id IS NULL;


SELECT COUNT(*) AS cases_without_review
FROM support_cases AS sc
WHERE NOT EXISTS (
  SELECT 1
  FROM human_reviews AS hr
  WHERE hr.case_id = sc.case_id
);

-- WITH keyword 

-- WITH name AS ( rough-work query )
-- > SELECT ... FROM name ...        <- one statement, no ; in between

-- For each issue type, how many cases are there,
--  and how many have at least one review

WITH reviewed_case_ids AS (
  SELECT DISTINCT case_id
  FROM human_reviews
)
SELECT ir.issue_type,
       COUNT(*) AS total_cases,
       COUNT(rc.case_id) AS reviewed_cases
FROM issue_records ir
LEFT JOIN reviewed_case_ids rc
  ON rc.case_id = ir.case_id
GROUP BY ir.issue_type
ORDER BY total_cases DESC, ir.issue_type;

-- Which validation rule caused the route?"
--  Meridian wants every rule in the answer, including rules that no review mentions





