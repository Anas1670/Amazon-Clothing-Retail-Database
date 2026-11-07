WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
-- ============================================================
-- Phase 4: Database Update Operations
-- Amazon Clothing Retail Store Database Management System
-- Fall 2026 | Section 001 | Team 5
-- ============================================================

SET SQLBLANKLINES ON
SET LINESIZE 150
SET PAGESIZE 100

-- Operation 1: UPDATE
-- Business scenario:
-- Increase the reorder threshold for InventoryID 4001
-- to maintain a higher minimum stock level.

PROMPT ===== BEFORE UPDATE =====

SELECT InventoryID,
       VariantID,
       PhysicalQuantity,
       AllocatedQuantity,
       ReorderThreshold
FROM F26_S001_T5_INVENTORY
WHERE InventoryID = 4001;

UPDATE F26_S001_T5_INVENTORY
SET ReorderThreshold = ReorderThreshold + 10
WHERE InventoryID = 4001;

PROMPT ===== AFTER UPDATE =====

SELECT InventoryID,
       VariantID,
       PhysicalQuantity,
       AllocatedQuantity,
       ReorderThreshold
FROM F26_S001_T5_INVENTORY
WHERE InventoryID = 4001;
-- ============================================================
-- Operation 2: INSERT
-- Business scenario:
-- Record a new warehouse packaging supply expense.
-- ============================================================

PROMPT ===== BEFORE INSERT =====

SELECT ExpenseNumber,
       ExpenseDate,
       Category,
       Description,
       Amount
FROM F26_S001_T5_OPERATING_COST
WHERE ExpenseNumber = 9050;

INSERT INTO F26_S001_T5_OPERATING_COST
    (ExpenseNumber, ExpenseDate, Category,
     Description, PaymentMethod, Amount, ExpenseType)
VALUES
    (9050, DATE '2026-11-06', 'Warehouse Supplies',
     'Packaging boxes and shipping tape',
     'Company Credit Card', 125.00, 'Operating');

PROMPT ===== AFTER INSERT =====

SELECT ExpenseNumber,
       ExpenseDate,
       Category,
       Description,
       Amount
FROM F26_S001_T5_OPERATING_COST
WHERE ExpenseNumber = 9050;
-- ============================================================
-- Operation 3: DELETE
-- Business scenario:
-- Remove an incorrectly recorded operating expense.
-- ============================================================

PROMPT ===== BEFORE DELETE =====

SELECT ExpenseNumber,
       ExpenseDate,
       Category,
       Description,
       Amount
FROM F26_S001_T5_OPERATING_COST
WHERE ExpenseNumber = 9045;

DELETE FROM F26_S001_T5_OPERATING_COST
WHERE ExpenseNumber = 9045;

PROMPT ===== AFTER DELETE =====

SELECT ExpenseNumber,
       ExpenseDate,
       Category,
       Description,
       Amount
FROM F26_S001_T5_OPERATING_COST
WHERE ExpenseNumber = 9045;

COMMIT;
