-- ============================================================
-- Phase 4: Database DROP Script
-- Amazon Clothing Retail Store Database Management System
-- Fall 2026 | Section 001 | Team 5
-- ============================================================

-- WARNING:
-- This script permanently deletes all 14 project tables
-- and their data. Execute only when intentionally resetting
-- the database.

-- Step 1: Drop dependent tables first.

DROP TABLE F26_S001_T5_RETURN;

DROP TABLE F26_S001_T5_ORDER_ITEM;

DROP TABLE F26_S001_T5_INVENTORY_LOCATION;

DROP TABLE F26_S001_T5_INVENTORY;

DROP TABLE F26_S001_T5_PURCHASE_ORDER_DETAIL;

DROP TABLE F26_S001_T5_PRODUCT_MATERIAL;

DROP TABLE F26_S001_T5_AMAZON_ORDER;

DROP TABLE F26_S001_T5_PURCHASE_ORDER;

DROP TABLE F26_S001_T5_PRODUCT_VARIANT;

-- Step 2: Drop parent tables.

DROP TABLE F26_S001_T5_CUSTOMER;

DROP TABLE F26_S001_T5_SUPPLIER;

DROP TABLE F26_S001_T5_PRODUCT;

DROP TABLE F26_S001_T5_EMPLOYEE;

DROP TABLE F26_S001_T5_OPERATING_COST;
