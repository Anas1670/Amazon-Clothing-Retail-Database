
SET LINESIZE 180
SET PAGESIZE 100

-- ============================================================
-- Query 1: Identify product variants requiring restocking.
--
-- Business question:
-- Which product variants have available inventory at or
-- below their reorder threshold, and how urgent is restocking?
--
-- Features: Multiple JOINs, CASE, calculated column, ORDER BY.
-- ============================================================

COLUMN ProductName FORMAT A25
COLUMN Brand FORMAT A18
COLUMN StockStatus FORMAT A18

SELECT
    pv.VariantID,
    p.ProductName,
    p.Brand,
    i.PhysicalQuantity,
    i.AllocatedQuantity,
    (i.PhysicalQuantity - i.AllocatedQuantity) AS AvailableStock,
    i.ReorderThreshold,
    CASE
        WHEN (i.PhysicalQuantity - i.AllocatedQuantity) = 0
            THEN 'OUT OF STOCK'
        WHEN (i.PhysicalQuantity - i.AllocatedQuantity) <= i.ReorderThreshold
            THEN 'REORDER NEEDED'
        ELSE 'SUFFICIENT'
    END AS StockStatus
FROM F26_S001_T5_INVENTORY i
JOIN F26_S001_T5_PRODUCT_VARIANT pv
    ON i.VariantID = pv.VariantID
JOIN F26_S001_T5_PRODUCT p
    ON pv.ProductID = p.ProductID
WHERE (i.PhysicalQuantity - i.AllocatedQuantity) <= i.ReorderThreshold
ORDER BY AvailableStock ASC, pv.VariantID;
-- ============================================================
-- Query 2: Sales performance by product category.
--
-- Business question:
-- Which product categories have sold at least 5 units,
-- and what are their total sales and average selling price?
--
-- Features: Multiple JOINs, SUM, AVG, COUNT,
--           GROUP BY, HAVING, ORDER BY.
-- ============================================================

PROMPT
PROMPT ===== QUERY 2: SALES BY PRODUCT CATEGORY =====

COLUMN Category FORMAT A20
COLUMN TotalRevenue FORMAT 9999990.00
COLUMN AverageSellingPrice FORMAT 999990.00

SELECT
    p.Category,
    COUNT(DISTINCT oi.OrderNumber) AS TotalOrders,
    SUM(oi.Quantity) AS TotalUnitsSold,
    ROUND(SUM(
        oi.Quantity * oi.SellingPricePerUnit - oi.Discount
    ), 2) AS TotalRevenue,
    ROUND(
        SUM(oi.Quantity * oi.SellingPricePerUnit)
        / NULLIF(SUM(oi.Quantity), 0),
        2
    ) AS AverageSellingPrice
FROM F26_S001_T5_ORDER_ITEM oi
JOIN F26_S001_T5_PRODUCT_VARIANT pv
    ON oi.VariantID = pv.VariantID
JOIN F26_S001_T5_PRODUCT p
    ON pv.ProductID = p.ProductID
GROUP BY p.Category
HAVING SUM(oi.Quantity) >= 5
ORDER BY TotalRevenue DESC;
