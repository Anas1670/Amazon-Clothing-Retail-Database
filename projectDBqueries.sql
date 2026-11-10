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

-- Expected output (verified in Oracle Omega, current database):
-- VariantID | ProductName             | AvailableStock | ReorderThreshold | StockStatus
-- 2012      | Formal Wrap Dress       | 20             | 25               | REORDER NEEDED
-- 2024      | Training Track Jacket   | 20             | 35               | REORDER NEEDED
-- 2036      | Linen Button-Up Shirt   | 20             | 20               | REORDER NEEDED
-- 2001      | Classic Cotton T-Shirt  | 27             | 30               | REORDER NEEDED
-- 2013      | Knit Sweater Dress      | 27             | 30               | REORDER NEEDED
-- 2014      | Maxi Evening Dress      | 34             | 35               | REORDER NEEDED
-- 6 rows selected.

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

-- Expected output (verified in Oracle Omega, current database):
-- Category     | TotalOrders | TotalUnitsSold | TotalRevenue | AverageSellingPrice
-- Outerwear    | 6           | 13             | 1646.87      | 126.68
-- Bottoms      | 8           | 17             | 744.13       | 43.77
-- Tops         | 9           | 18             | 703.62       | 39.09
-- Dresses      | 5           | 10             | 575.00       | 57.50
-- Activewear   | 7           | 11             | 402.19       | 36.56
-- Sleepwear    | 5           | 10             | 325.70       | 32.57
-- Accessories  | 3           | 6              | 139.44       | 23.24
-- Underwear    | 2           | 5              | 121.45       | 24.29
-- 8 rows selected.

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

-- Expected output (verified in Oracle Omega, current database):
-- Category    | Brand              | ReturnReason | ReturnCount | TotalRefund
-- Outerwear   | The North Face     | Wrong Size   | 1           | 483.47
-- Tops        | Lands' End         | Wrong Size   | 1           | 294.47
-- Activewear  | Nike               | Wrong Size   | 1           | 69.48
-- Tops        | Amazon Essentials  | Wrong Size   | 1           | 33.48
-- Bottoms     | Wrangler           | Wrong Size   | 1           | 27.19
-- Accessories | Fruit of the Loom  | Wrong Size   | 1           | 14.59
-- 6 rows selected.

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

-- Expected output (verified in Oracle Omega, current database):
-- SalesMonth | CategoryLabel  | UnitsSold | NetRevenue
-- 2026-03    | Bottoms        | 6         | 241.14
-- 2026-03    | Tops           | 11        | 293.29
-- 2026-03    | MONTH TOTAL    | 17        | 534.43
-- 2026-04    | Bottoms        | 3         | 112.47
-- 2026-04    | Dresses        | 10        | 575.00
-- 2026-04    | Outerwear      | 2         | 134.98
-- 2026-04    | MONTH TOTAL    | 15        | 822.45
-- 2026-05    | Activewear     | 6         | 168.24
-- 2026-05    | Outerwear      | 9         | 1259.91
-- 2026-05    | MONTH TOTAL    | 15        | 1428.15
-- 2026-06    | Activewear     | 3         | 134.97
-- 2026-06    | Sleepwear      | 10        | 325.70
-- 2026-06    | Underwear      | 2         | 53.98
-- 2026-06    | MONTH TOTAL    | 15        | 514.65
-- 2026-07    | Accessories    | 6         | 139.44
-- 2026-07    | Activewear     | 1         | 53.99
-- 2026-07    | Bottoms        | 3         | 126.87
-- 2026-07    | Tops           | 3         | 89.07
-- 2026-07    | Underwear      | 3         | 67.47
-- 2026-07    | MONTH TOTAL    | 16        | 476.84
-- 2026-08    | Activewear     | 1         | 44.99
-- 2026-08    | Bottoms        | 5         | 263.65
-- 2026-08    | Outerwear      | 2         | 251.98
-- 2026-08    | Tops           | 4         | 321.26
-- 2026-08    | MONTH TOTAL    | 12        | 881.88
-- ALL MONTHS | GRAND TOTAL    | 90        | 4658.40
-- 26 rows selected.

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

-- Expected output (verified in Oracle Omega, current database):
-- SupplierID | SupplierName                   | Net30Status | CreditLimit
-- 17         | Atlantic Fashion Trading       | Active      | 45000.00
-- 36         | Brightline Textile Group       | Inactive    | 40000.00
-- 26         | Brookfield Clothing Partners   | Active      | 40000.00
-- 37         | Capital Garment Supply         | Active      | 45000.00
-- 7          | Coastal Denim Distributors     | Active      | 45000.00
-- 43         | Crown Apparel Wholesale        | Active      | 25000.00
-- 3          | Evergreen Fabric Distributors  | Active      | 25000.00
-- 33         | Frontier Clothing Wholesale    | Active      | 25000.00
-- 42         | Global Stitch Partners         | Active      | 20000.00
-- 2          | Golden State Apparel Supply    | Active      | 20000.00
-- 22         | Harbor Fashion Wholesale       | Active      | 20000.00
-- 38         | Horizon Fashion Wholesale      | Active      | 50000.00
-- 28         | Lakeside Garment Wholesale     | Inactive    | 50000.00
-- 11         | Liberty Textile Trading        | Active      | 15000.00
-- 27         | Meridian Textile Supply        | Active      | 45000.00
-- 13         | Oakwood Fashion Distributors   | Active      | 25000.00
-- 1          | Pacific Cotton Textiles        | Active      | 15000.00
-- 23         | Prime Stitch Textiles          | Active      | 25000.00
-- 41         | Riverside Textile Trading      | Active      | 15000.00
-- 32         | Royal Thread Supply            | Inactive    | 20000.00
-- 12         | Silverline Clothing Supply     | Inactive    | 20000.00
-- 31         | Skyline Apparel Trading        | Active      | 15000.00
-- 21         | Sterling Garment Distributors  | Active      | 15000.00
-- 6          | Summit Fashion Supply          | Active      | 40000.00
-- 8          | Urban Thread Wholesale         | Inactive    | 50000.00
-- 16         | Valley Knitwear Supply         | Inactive    | 40000.00
-- 18         | Westbrook Apparel Group        | Active      | 50000.00
-- 27 rows selected.

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

-- Expected output (verified in Oracle Omega, current database):
-- SalesMonth | VariantID | ProductName                 | Brand             | UnitsSold | NetRevenue | RevenueRank | MonthlyRevenuePct
-- 2026-03    | 2008      | High Rise Leggings          | CRZ Yoga          | 3         | 97.17      | 1           | 18.18
-- 2026-03    | 2002      | Slim Fit Oxford Shirt       | Goodthreads       | 3         | 94.47      | 2           | 17.68
-- 2026-03    | 2007      | Slim Fit Chinos             | Dockers           | 2         | 89.98      | 3           | 16.84
-- 2026-04    | 2014      | Maxi Evening Dress          | Ever-Pretty       | 3         | 215.97     | 1           | 26.26
-- 2026-04    | 2016      | Lightweight Windbreaker     | Columbia          | 2         | 134.98     | 2           | 16.41
-- 2026-04    | 2011      | Floral Summer Dress         | Amazon Essentials | 3         | 116.07     | 3           | 14.11
-- 2026-05    | 2020      | Wool Blend Overcoat         | Calvin Klein      | 3         | 512.97     | 1           | 35.92
-- 2026-05    | 2017      | Puffer Winter Jacket        | The North Face    | 3         | 485.97     | 2           | 34.03
-- 2026-05    | 2019      | Waterproof Raincoat         | Columbia          | 2         | 179.98     | 3           | 12.60
-- 2026-06    | 2026      | Cotton Pajama Set           | Amazon Essentials | 3         | 105.27     | 1           | 20.45
-- 2026-06    | 2029      | Flannel Pajama Shirt        | Lands' End        | 3         | 99.87      | 2           | 19.41
-- 2026-06    | 2025      | Workout Training Tee        | Nike              | 2         | 71.98      | 3           | 13.99
-- 2026-07    | 2038      | Corduroy Trousers           | Amazon Essentials | 3         | 126.87     | 1           | 26.61
-- 2026-07    | 2035      | Leather Casual Belt         | Dockers           | 3         | 80.97      | 2           | 16.98
-- 2026-07    | 2032      | Seamless Briefs             | Hanes             | 3         | 67.47      | 3           | 14.15
-- 2026-08    | 2041      | Cashmere Blend Sweater      | Lands' End        | 3         | 296.97     | 1           | 33.67
-- 2026-08    | 2040      | Quilted Bomber Jacket       | Alpha Industries  | 2         | 251.98     | 2           | 28.57
-- 2026-08    | 2044      | Faux Leather Skirt          | Calvin Klein      | 3         | 175.47     | 3           | 19.90
-- 18 rows selected.

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
