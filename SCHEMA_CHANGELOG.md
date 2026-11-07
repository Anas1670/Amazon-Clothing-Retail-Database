# Schema reconciliation change log

**Project:** Amazon Clothing Retail Store Database — Fall 2026, Section 001, Team 5
**Baseline:** original `projectDBcreate.sql` as received.
**Purpose:** Make the schema consistent with `projectDBInsert.sql` (630 rows) and the previously tested Omega `projectDBupdate.sql`, without replacing the original table definitions.

## Changes made

1. Supplier status length and default changed to match Active/Inactive records.
2. Supplier status check matches seeded values.
3. VariantSize column matches INSERT and existing Omega schema.
4. Purchase-order status documentation synchronized.
5. Purchase-order report comment case synchronized.
6. Purchase-order status check synchronized with actual rows.
7. Received status/date integrity check updated.
8. Non-received status/date integrity check updated.
9. Amazon order number type matches Omega numeric schema.
10. Order item order number type matches parent.
11. Return order number type matches parent.
12. Shipping service check extended to Standard while retaining Priority.
13. Operating cost type check matches inserts and UPDATE; old labels not used by current scripts.
14. Added SQL*Plus SET SQLBLANKLINES ON at script start.

## Preserved from original version

- All 14 CREATE TABLE statements and their original table order.
- Primary keys, foreign keys, unique constraints, and the employee self-reference.
- Supplier credit, savings, lead-time and minimum-order-quantity checks.
- Inventory quantity and allocation checks.
- Purchase-order date checks and received-status/date consistency checks (with status spelling aligned).
- Purchase-order detail and order-item nonnegative discount checks.
- Shipping carrier, monetary, package, date and shipping-information checks (with Standard service added).
- Return financial checks, employee salary and self-supervision checks.
- Existing column widths except where an incompatible value or column name required adjustment.

## Validation and limitations

- Reviewed INSERT statements: 45 rows per table, 630 total.
- INSERT values observed: supplier statuses Active/Inactive; purchase-order statuses Pending/Shipped/Received; shipping services Ground/Standard/Express; operating expense types Fixed/Variable.
- The previously executed UPDATE adds an operating expense with ExpenseType Operating.
- Both discount fields are zero in all 45 seeded rows for their respective tables.
- This is a static compatibility reconciliation, **not a fresh Oracle execution test**. Before replacing the committed CREATE file, test the revised CREATE and INSERT scripts in a separate clean schema or obtain team review. **Do not drop or recreate the populated Omega tables.**
- `Net30Status` remains the original column name even though the supplied values describe supplier activity, not Net-30 payment eligibility. Consider discussing its semantics with the team before final submission.
- `OrderNumber` is numeric to match the existing Omega schema and INSERT data. If the intended business requirement is alphanumeric Amazon order IDs, the team should explicitly decide on a consistent VARCHAR2 design across all related tables and data.
