SET TAB OFF
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

-- ============================================================
-- Query 3: Return reasons related to size or fit.
--
-- English:
-- For each product category, brand, and recorded return reason
-- containing "size" or "fit", show the number of return records
-- and total refund amount. Include groups with at least one
-- return and list the most frequent reasons first.
--
-- Features: Multiple JOINs, LIKE, GROUP BY, HAVING, aggregates.
-- ============================================================

PROMPT
PROMPT ===== QUERY 3: SIZE AND FIT RETURN REASONS =====

COLUMN Category FORMAT A18
COLUMN Brand FORMAT A20
COLUMN ReturnReason FORMAT A40
COLUMN ReturnCount FORMAT 999990
COLUMN TotalRefund FORMAT 9999990.00

SELECT
    p.Category,
    p.Brand,
    r.Reason AS ReturnReason,
    COUNT(*) AS ReturnCount,
    ROUND(SUM(r.RefundAmount), 2) AS TotalRefund
FROM F26_S001_T5_RETURN r
JOIN F26_S001_T5_ORDER_ITEM oi
    ON r.OrderNumber = oi.OrderNumber
   AND r.LineItemNumber = oi.LineItemNumber
JOIN F26_S001_T5_PRODUCT_VARIANT pv
    ON oi.VariantID = pv.VariantID
JOIN F26_S001_T5_PRODUCT p
    ON pv.ProductID = p.ProductID
WHERE LOWER(r.Reason) LIKE '%size%'
   OR LOWER(r.Reason) LIKE '%fit%'
GROUP BY p.Category, p.Brand, r.Reason
HAVING COUNT(*) >= 1
ORDER BY ReturnCount DESC, TotalRefund DESC,
         p.Category, p.Brand, r.Reason;


-- ============================================================
-- Query 4: Monthly category sales with subtotals.
--
-- English:
-- Show net sales revenue and units sold for each month and
-- product category, followed by each month's subtotal and
-- an overall grand total.
--
-- Features: Multiple JOINs, ROLLUP, GROUPING, CASE, aggregates.
-- ============================================================

PROMPT
PROMPT ===== QUERY 4: MONTHLY CATEGORY SALES ROLLUP =====

COLUMN SalesMonth FORMAT A12
COLUMN CategoryLabel FORMAT A22
COLUMN UnitsSold FORMAT 9999990
COLUMN NetRevenue FORMAT 9999990.00

SELECT
    CASE
        WHEN GROUPING(TRUNC(ao.OrderDate, 'MM')) = 1
            THEN 'ALL MONTHS'
        ELSE TO_CHAR(TRUNC(ao.OrderDate, 'MM'), 'YYYY-MM')
    END AS SalesMonth,
    CASE
        WHEN GROUPING(TRUNC(ao.OrderDate, 'MM')) = 1
            THEN 'GRAND TOTAL'
        WHEN GROUPING(p.Category) = 1
            THEN 'MONTH TOTAL'
        ELSE p.Category
    END AS CategoryLabel,
    SUM(oi.Quantity) AS UnitsSold,
    ROUND(
        SUM(oi.Quantity * oi.SellingPricePerUnit - oi.Discount),
        2
    ) AS NetRevenue
FROM F26_S001_T5_AMAZON_ORDER ao
JOIN F26_S001_T5_ORDER_ITEM oi
    ON ao.OrderNumber = oi.OrderNumber
JOIN F26_S001_T5_PRODUCT_VARIANT pv
    ON oi.VariantID = pv.VariantID
JOIN F26_S001_T5_PRODUCT p
    ON pv.ProductID = p.ProductID
GROUP BY ROLLUP (
    TRUNC(ao.OrderDate, 'MM'),
    p.Category
)
ORDER BY
    GROUPING(TRUNC(ao.OrderDate, 'MM')),
    TRUNC(ao.OrderDate, 'MM'),
    GROUPING(p.Category),
    p.Category;


-- ============================================================
-- Query 5: Supplier purchase-history coverage.
--
-- English:
-- Find suppliers for whom every product variant assigned to
-- that supplier has appeared in at least one received purchase
-- order issued to that same supplier.
-- Exclude suppliers with no assigned variants.
--
-- Features: Relational division, correlated nested subqueries,
--           NOT EXISTS, JOIN.
-- ============================================================

PROMPT
PROMPT ===== QUERY 5: SUPPLIERS COVERING ALL ASSIGNED VARIANTS =====

COLUMN SupplierName FORMAT A30
COLUMN Net30Status FORMAT A12
COLUMN CreditLimit FORMAT 9999990.00

SELECT
    s.SupplierID,
    s.SupplierName,
    s.Net30Status,
    s.CreditLimit
FROM F26_S001_T5_SUPPLIER s
WHERE EXISTS (
    SELECT 1
    FROM F26_S001_T5_PRODUCT_VARIANT pv
    WHERE pv.SupplierID = s.SupplierID
)
AND NOT EXISTS (
    SELECT 1
    FROM F26_S001_T5_PRODUCT_VARIANT pv
    WHERE pv.SupplierID = s.SupplierID
      AND NOT EXISTS (
          SELECT 1
          FROM F26_S001_T5_PURCHASE_ORDER po
          JOIN F26_S001_T5_PURCHASE_ORDER_DETAIL pod
              ON po.PurchaseOrderID = pod.PurchaseOrderID
          WHERE po.SupplierID = s.SupplierID
            AND po.Status = 'Received'
            AND pod.VariantID = pv.VariantID
      )
)
ORDER BY s.SupplierName, s.SupplierID;


-- ============================================================
-- Query 6: Top three revenue ranks of variants each month.
--
-- English:
-- Calculate each product variant's monthly units sold and
-- net revenue. Rank variants within each month by net revenue
-- and show the top three distinct revenue ranks, including ties.
-- Also show each variant's percentage of that month's revenue.
--
-- Features: Multiple JOINs, CTEs, GROUP BY, DENSE_RANK OVER,
--           SUM OVER, nested filtering.
-- ============================================================

PROMPT
PROMPT ===== QUERY 6: MONTHLY TOP VARIANTS =====

COLUMN SalesMonth FORMAT A10
COLUMN ProductName FORMAT A28
COLUMN Brand FORMAT A20
COLUMN NetRevenue FORMAT 9999990.00
COLUMN MonthlyRevenuePct FORMAT 990.00
COLUMN RevenueRank FORMAT 9990

SELECT
    TO_CHAR(rs.MonthStart, 'YYYY-MM') AS SalesMonth,
    rs.VariantID,
    rs.ProductName,
    rs.Brand,
    rs.UnitsSold,
    ROUND(rs.NetRevenue, 2) AS NetRevenue,
    rs.RevenueRank,
    rs.MonthlyRevenuePct
FROM (
    SELECT
        ms.MonthStart,
        ms.VariantID,
        ms.ProductName,
        ms.Brand,
        ms.UnitsSold,
        ms.NetRevenue,
        DENSE_RANK() OVER (
            PARTITION BY ms.MonthStart
            ORDER BY ms.NetRevenue DESC
        ) AS RevenueRank,
        ROUND(
            100 * ms.NetRevenue
            / NULLIF(
                SUM(ms.NetRevenue) OVER (
                    PARTITION BY ms.MonthStart
                ),
                0
            ),
            2
        ) AS MonthlyRevenuePct
    FROM (
        SELECT
            TRUNC(ao.OrderDate, 'MM') AS MonthStart,
            pv.VariantID,
            p.ProductName,
            p.Brand,
            SUM(oi.Quantity) AS UnitsSold,
            SUM(
                oi.Quantity * oi.SellingPricePerUnit
                - oi.Discount
            ) AS NetRevenue
        FROM F26_S001_T5_AMAZON_ORDER ao
        JOIN F26_S001_T5_ORDER_ITEM oi
            ON ao.OrderNumber = oi.OrderNumber
        JOIN F26_S001_T5_PRODUCT_VARIANT pv
            ON oi.VariantID = pv.VariantID
        JOIN F26_S001_T5_PRODUCT p
            ON pv.ProductID = p.ProductID
        GROUP BY
            TRUNC(ao.OrderDate, 'MM'),
            pv.VariantID,
            p.ProductName,
            p.Brand
    ) ms
) rs
WHERE rs.RevenueRank <= 3
ORDER BY rs.MonthStart, rs.RevenueRank, rs.VariantID;


-- ============================================================
-- Query 7: Product price similarity recommendations.
--
-- Business question:
-- Which five product variants have pricing characteristics
-- most similar to the Classic Cotton T-Shirt (Variant 2001),
-- based on MSRP and selling price?
--
-- Features: Multiple JOINs, VECTOR_DISTANCE, TO_VECTOR,
--           ORDER BY, FETCH FIRST.
-- ============================================================

PROMPT
PROMPT ===== QUERY 7: PRODUCT PRICE SIMILARITY =====

COLUMN ProductName FORMAT A25
COLUMN Category FORMAT A20
COLUMN PriceDistance FORMAT 999990.00

SELECT
    pv.VariantID,
    p.ProductName,
    p.Category,
    p.MSRP,
    pv.SellingPrice,
    ROUND(
        VECTOR_DISTANCE(
            VECTOR('[19.99,17.99]'),
            TO_VECTOR(
                '[' || TO_CHAR(p.MSRP, 'FM999990D00', 'NLS_NUMERIC_CHARACTERS=''.,''')
                || ',' ||
                TO_CHAR(pv.SellingPrice, 'FM999990D00', 'NLS_NUMERIC_CHARACTERS=''.,''')
                || ']'
            ),
            EUCLIDEAN
        ),
        2
    ) AS PriceDistance
FROM F26_S001_T5_PRODUCT_VARIANT pv
JOIN F26_S001_T5_PRODUCT p
    ON pv.ProductID = p.ProductID
WHERE pv.VariantID <> 2001
ORDER BY PriceDistance ASC, pv.VariantID
FETCH FIRST 5 ROWS ONLY;

-- Expected output (verified in Oracle Omega):
--
-- VariantID  ProductName             Category      MSRP   SellingPrice  PriceDistance
-- 2033       Everyday Crew Socks     Accessories   18.99  17.09         1.35
-- 2005       Ribbed Tank Top         Tops          16.99  15.29         4.04
-- 2034       Winter Knit Beanie      Accessories   22.99  20.69         4.04
-- 2032       Seamless Briefs         Underwear     24.99  22.49         6.73
-- 2042       Cotton Henley Shirt     Tops          26.99  24.29         9.42
--
-- 5 rows selected.
