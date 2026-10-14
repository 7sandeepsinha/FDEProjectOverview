-- Section 7 | Run only this statement in S, which has NORTH-view privilege only.
-- Access denied is expected; S cannot use the SOUTH-view interface.
SELECT * FROM meridian_retail.class11_support_south_view LIMIT 4;
