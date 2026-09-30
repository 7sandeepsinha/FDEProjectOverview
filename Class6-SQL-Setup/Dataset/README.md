# Meridian Retail MySQL dataset pack

This pack carries the five trusted Class 5 files into a connected MySQL 8
database, then evolves that database in stages through Classes 8–11. The data is
deterministic: every reset produces the same identifiers, counts and teaching
examples.

## Compatibility

- MySQL Community Server 8.0.18 or later
- MySQL Workbench
- InnoDB and `utf8mb4`
- An account that can create a database and temporary tables
- Class 11 role setup additionally requires `CREATE ROLE`/`GRANT` privileges

MySQL 8.0.18 is the minimum because the Class 10 lab uses `EXPLAIN ANALYZE`.
The base schema uses enforced `CHECK` constraints and window functions available
in this MySQL 8 range.

## Run order

Run each complete file in a single Workbench connection and wait for it to
finish before moving to the next file.

| Teaching checkpoint | Run these files | Result |
|---|---|---|
| Classes 6–7 | `00_base_schema.sql`, `01_seed_base_data.sql`, `02_verify_base_dataset.sql` | Five connected Class 5 tables |
| Class 8 | Add `03_class8_model_evolution.sql` | Normalized customer/product/routing model, one-to-many issues, view and denormalized snapshot |
| Class 9 | Add `04_class9_acid_extension.sql` | Inventory, payments, status history and atomic stored procedure |
| Class 9 labs | Open `05_class9_transaction_labs.sql` | Rollback, pessimistic locking and optimistic locking exercises |
| Class 10 | Add `06_class10_performance_extension.sql` | 250,000 case events, before/after plans and teaching indexes |
| Class 11 | Add `07_class11_security_extension.sql` | Classification, masked views, audit triggers and roles |
| Final check | Run `08_verify_full_evolution.sql` | Counts, orphans, reconciliations and anchor cases |

To return to the Class 6 starting point, run `00_base_schema.sql` again and then
`01_seed_base_data.sql`. `00_base_schema.sql` intentionally drops and recreates
the `meridian_retail` database, so do not point it at a database containing work
you need to keep.

## Class 6–7 baseline

The baseline contains exactly five tables:

| Table | Grain | Rows | Relationship |
|---|---|---:|---|
| `orders` | One row per order | 20,000 | One order can have many support cases |
| `support_cases` | One row per case | 25,000 | A case may have an order; RETURN/DAMAGE must have one |
| `issue_records` | One trusted issue row per case | 25,000 | One-to-one at this checkpoint |
| `human_reviews` | One row per review event | 10,000 | 8,000 reviewed cases; 2,000 follow-up events |
| `validation_rules` | One row per validation rule | 12 | A rule may trigger many review events |

The Class 5 anchors remain unchanged and easy to find:

- `MCS-501` / `MR-501`: complete, internally consistent evidence
- `MCS-502` / `MR-502`: readable but conflicting delivery dates, routed by
  `VR-006` to review `MHR-502`

## Deliberate schema decisions

1. `validation_rules.condition` is named `condition_text` in MySQL because
   `CONDITION` is a reserved word.
2. `human_reviews.triggered_rule_id` is a nullable foreign key at the five-table
   baseline. It makes the Class 5 handoff question answerable without inventing
   a sixth table. Class 8 then normalizes this relationship into `case_routes`.
3. `human_reviews.handling_minutes` supports aggregate, outlier and workload
   exercises without changing the table's review-event grain.
4. `support_cases.order_id` is nullable for GENERAL enquiries; RETURN and DAMAGE
   cases require an order through a `CHECK` constraint.
5. `issue_records.case_id` is both primary and foreign key at baseline. Class 8
   introduces `issue_id` and additional issue rows to demonstrate a controlled
   one-to-one to one-to-many evolution.

## Data-quality posture

The connected database represents the trusted layer. It contains realistic and
valid operational complexity—nullable optional relationships, stale extracts,
multiple cases per order, repeat reviews, unresolved work, skewed categories,
payment failures and readable cross-source disagreements. Rows that violate
basic structure, such as malformed dates, duplicate primary keys or broken
foreign keys, belong in the raw/rejected-load exercises from Class 5 rather than
inside these trusted tables.

The generated contact details use the reserved `example.test` domain and do not
represent real customers.

## Later-class readiness

- **Class 6:** CRUD, inner/left joins, `GROUP BY`, `HAVING`, counts and averages.
- **Class 7:** correlated subqueries, CTEs, views, multi-table analysis and
  `ROW_NUMBER`, `RANK`, `LAG` and `LEAD` over review histories.
- **Class 8:** 3NF dimensions, foreign keys, relationship changes, naming,
  normalized view versus refreshable denormalized snapshot.
- **Class 9:** transaction boundaries across orders, inventory and payments;
  rollback, idempotency, row locks and optimistic version checks.
- **Class 10:** selective single/composite indexes and a 250,000-row activity
  workload for `EXPLAIN ANALYZE` comparisons.
- **Class 11:** PII classification, masked access views, least-privilege roles
  and transactional audit triggers. MySQL does not provide a general native
  row-level-security policy feature, so the pack teaches a view-and-grant access
  pattern rather than labeling it as native RLS.

## Expected deterministic milestones

After `01_seed_base_data.sql`:

- 20,000 orders
- 25,000 cases and issue rows
- 10,000 review events across 8,000 cases
- all four review-trigger rules represented: `VR-006`, `VR-010`, `VR-011`,
  `VR-012`

After all migrations:

- 20,001 orders, including `MR-LAB-001`
- 26,470 issue rows after the one-to-many evolution
- 15,000 customers and 16 products
- 3,564 route events
- 22,000 payment-attempt rows
- 250,000 case-activity events

## Operational notes

- The seed is set-based rather than a giant list of inserts, so the package is
  compact and repeatable.
- Run the files as scripts, not by highlighting isolated statements containing
  `DELIMITER` blocks.
- `03_class8_model_evolution.sql` and later files are migrations, not reset
  scripts. To repeat one cleanly, reset to the base and re-run the sequence.
- The Class 11 script intentionally creates roles but not users and never assigns
  a role to an account automatically.

