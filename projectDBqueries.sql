SET TAB OFF
SET SQLBLANKLINES ON
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

PROMPT
PROMPT ===== QUERY 1: INVENTORY RESTOCKING ANALYSIS =====

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

-- Expected output (verified in Oracle Omega, current database):
-- Category    | Brand              | ReturnReason | ReturnCount | TotalRefund
-- Outerwear   | The North Face     | Wrong Size   | 1           | 483.47
-- Tops        | Lands' End         | Wrong Size   | 1           | 294.47
-- Activewear  | Nike               | Wrong Size   | 1           | 69.48
-- Tops        | Amazon Essentials  | Wrong Size   | 1           | 33.48
-- Bottoms     | Wrangler           | Wrong Size   | 1           | 27.19
-- Accessories | Fruit of the Loom  | Wrong Size   | 1           | 14.59
-- 6 rows selected.

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
-- 2026-08    | MONTH TOTAL    | 12         | 881.88
-- ALL MONTHS | GRAND TOTAL    | 90        | 4658.40
-- 26 rows selected.

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
-- 41         | Riverside Textile Trading     | Active      | 15000.00
-- 32         | Royal Thread Supply            | Inactive    | 20000.00
-- 12         | Silverline Clothing Supply     | Inactive    | 20000.00
-- 31         | Skyline Apparel Trading       | Active      | 15000.00
-- 21         | Sterling Garment Distributors | Active      | 15000.00
-- 6          | Summit Fashion Supply          | Active      | 40000.00
-- 8          | Urban Thread Wholesale        | Inactive    | 50000.00
-- 16         | Valley Knitwear Supply        | Inactive    | 40000.00
-- 18         | Westbrook Apparel Group       | Active      | 50000.00
-- 27 rows selected.

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
-- 2026-08    | 2044      | Faux Leather Skirt         | Calvin Klein      | 3         | 175.47     | 3           | 19.90
-- 18 rows selected.

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
-- VariantID  ProductName             Category      MSRP   SellingPrice  PriceDistance
-- 2033       Everyday Crew Socks     Accessories   18.99  17.09         1.35
-- 2005       Ribbed Tank Top         Tops          16.99  15.29         4.04
-- 2034       Winter Knit Beanie      Accessories   22.99  20.69         4.04
-- 2032       Seamless Briefs         Underwear     24.99  22.49         6.73
-- 2042       Cotton Henley Shirt     Tops          26.99  24.29         9.42
-- 5 rows selected.

-- ============================================================
-- Query 8: Return cost analysis by category and brand.
--
-- English:
-- Calculate the number of returns, total refunds,
-- total return shipping costs, total restocking fees,
-- and net return-related cost for each product category
-- and brand. Display the ten groups with the highest
-- net return-related costs.
--
-- Net Return Cost = Refund Amount
--                  + Return Shipping Cost
--                  - Restocking Fee
--
-- Features: Multiple JOINs, GROUP BY, aggregate functions,
-- calculated column, ORDER BY, FETCH FIRST.
-- ============================================================

PROMPT
PROMPT ===== QUERY 8: RETURN COST ANALYSIS =====

COLUMN Category FORMAT A18
COLUMN Brand FORMAT A22
COLUMN ReturnCount FORMAT 999990
COLUMN TotalRefund FORMAT 9999990.00
COLUMN ReturnShipping FORMAT 999990.00
COLUMN RestockingFees FORMAT 999990.00
COLUMN NetReturnCost FORMAT 9999990.00

SELECT
    p.Category,
    p.Brand,
    COUNT(r.ReturnNumber) AS ReturnCount,
    ROUND(SUM(r.RefundAmount), 2) AS TotalRefund,
    ROUND(SUM(r.ReturnShippingCost), 2) AS ReturnShipping,
    ROUND(SUM(r.RestockingFee), 2) AS RestockingFees,
    ROUND(
        SUM(
            r.RefundAmount
            + r.ReturnShippingCost
            - r.RestockingFee
        ),
        2
    ) AS NetReturnCost
FROM F26_S001_T5_RETURN r
JOIN F26_S001_T5_ORDER_ITEM oi
    ON r.OrderNumber = oi.OrderNumber
   AND r.LineItemNumber = oi.LineItemNumber
JOIN F26_S001_T5_PRODUCT_VARIANT pv
    ON oi.VariantID = pv.VariantID
JOIN F26_S001_T5_PRODUCT p
    ON pv.ProductID = p.ProductID
GROUP BY
    p.Category,
    p.Brand
ORDER BY
    NetReturnCost DESC,
    p.Category,
    p.Brand
FETCH FIRST 10 ROWS ONLY;

-- Expected output (initial populated database, before updates; verified in Oracle Omega):
-- CATEGORY    BRAND                 RETURNCOUNT TOTALREFUND RETURNSHIPPING RESTOCKINGFEES NETRETURNCOST
-- Outerwear   Calvin Klein          1           510.47      4.99           2.50           512.96
-- Outerwear   The North Face        1           483.47      4.99           2.50           485.96
-- Outerwear   Columbia              2           312.46      4.99           2.50           314.95
-- Tops        Lands' End            1           294.47      4.99           2.50           296.96
-- Outerwear   Alpha Industries      1           251.98      0.00           0.00           251.98
-- Dresses     Ever-Pretty           1           213.47      4.99           2.50           215.96
-- Bottoms     Calvin Klein          1           172.97      4.99           2.50           175.46
-- Bottoms     The Drop              2           168.46      4.99           2.50           170.95
-- Tops        Goodthreads           2           130.66      4.99           2.50           133.15
-- Bottoms     Amazon Essentials     1           124.37      4.99           2.50           126.86
-- 10 rows selected.

-- ============================================================
-- Query 9: Supplier delivery performance analysis.
--
-- English:
-- Analyze supplier performance by displaying total purchase
-- orders, received orders, shipped orders, pending orders,
-- on-time deliveries, late deliveries, on-time delivery
-- percentage, and average days late.
--
-- Delivery performance is calculated only for received orders.
--
-- Features: JOIN, GROUP BY, aggregate functions, CASE,
--           calculated percentage, ORDER BY.
-- ============================================================

PROMPT
PROMPT ===== QUERY 9: SUPPLIER DELIVERY PERFORMANCE =====

COLUMN SupplierName FORMAT A32
COLUMN OnTimePercentage FORMAT 990.00
COLUMN AverageDaysLate FORMAT 990.00

SELECT
    s.SupplierID,
    s.SupplierName,
    COUNT(po.PurchaseOrderID) AS TotalOrders,
    SUM(CASE WHEN po.Status = 'Received' THEN 1 ELSE 0 END)
        AS ReceivedOrders,
    SUM(CASE WHEN po.Status = 'Shipped' THEN 1 ELSE 0 END)
        AS ShippedOrders,
    SUM(CASE WHEN po.Status = 'Pending' THEN 1 ELSE 0 END)
        AS PendingOrders,
    SUM(CASE
        WHEN po.Status = 'Received'
         AND po.DateReceived <= po.EstimatedDeliveryDate
        THEN 1 ELSE 0
    END) AS OnTimeOrders,
    SUM(CASE
        WHEN po.Status = 'Received'
         AND po.DateReceived > po.EstimatedDeliveryDate
        THEN 1 ELSE 0
    END) AS LateOrders,
    ROUND(
        100 * SUM(CASE
            WHEN po.Status = 'Received'
             AND po.DateReceived <= po.EstimatedDeliveryDate
            THEN 1 ELSE 0
        END)
        / NULLIF(SUM(CASE
            WHEN po.Status = 'Received' THEN 1 ELSE 0
        END), 0),
        2
    ) AS OnTimePercentage,
    ROUND(
        AVG(CASE
            WHEN po.Status = 'Received'
            THEN GREATEST(
                po.DateReceived - po.EstimatedDeliveryDate,
                0
            )
        END),
        2
    ) AS AverageDaysLate
FROM F26_S001_T5_SUPPLIER s
JOIN F26_S001_T5_PURCHASE_ORDER po
    ON s.SupplierID = po.SupplierID
GROUP BY
    s.SupplierID,
    s.SupplierName
ORDER BY
    LateOrders DESC,
    AverageDaysLate DESC,
    s.SupplierName;

-- Expected output (initial populated database, before updates; verified in Oracle Omega):
-- SupplierID | SupplierName                    | Total | Received | Shipped | Pending | OnTime | Late | OnTime% | AvgDaysLate
--  29 | Aspire Fashion Distributors      | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--   5 | Blue Ridge Textile Group         | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  24 | Canyon Apparel Supply            | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--  30 | Cedar Valley Textiles            | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  45 | Continental Fashion Textiles     | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  19 | Crescent Textile Partners        | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--  34 | Diamond Fabric Partners          | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--  40 | Elite Cotton Distributors        | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  25 | Grandview Fabric Company         | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--   9 | Heritage Garment Supply          | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--  35 | Maple Grove Apparel              | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  14 | Metro Garment Wholesale          | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--   4 | Northstar Clothing Wholesale     | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--  15 | Pioneer Cotton Company           | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  44 | Premier Garment Supply           | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--  20 | Redwood Clothing Supply          | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  39 | Stonebridge Clothing Supply      | 1 | 0 | 1 | 0 | 0 | 0 | NULL | NULL
--  10 | Sunrise Apparel Partners         | 1 | 0 | 0 | 1 | 0 | 0 | NULL | NULL
--  17 | Atlantic Fashion Trading         | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  36 | Brightline Textile Group         | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  26 | Brookfield Clothing Partners     | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  37 | Capital Garment Supply           | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--   7 | Coastal Denim Distributors       | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  43 | Crown Apparel Wholesale          | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--   3 | Evergreen Fabric Distributors    | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  33 | Frontier Clothing Wholesale      | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  42 | Global Stitch Partners           | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--   2 | Golden State Apparel Supply      | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  22 | Harbor Fashion Wholesale         | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  38 | Horizon Fashion Wholesale        | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  28 | Lakeside Garment Wholesale       | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  11 | Liberty Textile Trading          | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  27 | Meridian Textile Supply          | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  13 | Oakwood Fashion Distributors     | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--   1 | Pacific Cotton Textiles          | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  23 | Prime Stitch Textiles            | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  41 | Riverside Textile Trading       | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  32 | Royal Thread Supply              | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  12 | Silverline Clothing Supply       | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  31 | Skyline Apparel Trading          | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  21 | Sterling Garment Distributors    | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--   6 | Summit Fashion Supply            | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--   8 | Urban Thread Wholesale           | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  16 | Valley Knitwear Supply           | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
--  18 | Westbrook Apparel Group          | 1 | 1 | 0 | 0 | 1 | 0 | 100.00% | 0.00
-- 45 rows selected.

-- ============================================================
-- Query 10: Shipping carrier and service performance analysis.
--
-- English:
--
-- Compare shipping carriers and shipping services by
-- calculating the number of orders shipped, customers served,
-- average shipping cost, average package weight, average
-- delivery time, on-time deliveries, late deliveries, and
-- on-time delivery percentage.
--
-- Features: JOIN, GROUP BY, aggregate functions, CASE,
--           calculated percentage, ORDER BY.
-- ============================================================

PROMPT
PROMPT ===== QUERY 10: SHIPPING PERFORMANCE ANALYSIS =====

COLUMN ShippingCarrier FORMAT A16
COLUMN ShippingService FORMAT A14
COLUMN TotalOrders FORMAT 999
COLUMN CustomersServed FORMAT 999
COLUMN AverageShippingCost FORMAT 990.00
COLUMN AverageWeight FORMAT 990.00
COLUMN AverageDeliveryDays FORMAT 990.00
COLUMN OnTimeOrders FORMAT 999
COLUMN LateOrders FORMAT 999
COLUMN OnTimePercentage FORMAT 990.00

SELECT
    ao.ShippingCarrier,
    ao.ShippingService,
    COUNT(ao.OrderNumber) AS TotalOrders,
    COUNT(DISTINCT ao.CustomerID) AS CustomersServed,
    ROUND(AVG(ao.ShippingCost), 2) AS AverageShippingCost,
    ROUND(AVG(ao.PackageWeight), 2) AS AverageWeight,
    ROUND(
        AVG(ao.ActualDeliveryDate - ao.ShippingDate),
        2
    ) AS AverageDeliveryDays,
    SUM(
        CASE
            WHEN ao.ActualDeliveryDate <= ao.ExpectedDate
            THEN 1
            ELSE 0
        END
    ) AS OnTimeOrders,
    SUM(
        CASE
            WHEN ao.ActualDeliveryDate > ao.ExpectedDate
            THEN 1
            ELSE 0
        END
    ) AS LateOrders,
    ROUND(
        100 * SUM(
            CASE
                WHEN ao.ActualDeliveryDate <= ao.ExpectedDate
                THEN 1
                ELSE 0
            END
        ) / COUNT(ao.OrderNumber),
        2
    ) AS OnTimePercentage
FROM F26_S001_T5_AMAZON_ORDER ao
JOIN F26_S001_T5_CUSTOMER c
    ON ao.CustomerID = c.CustomerID
WHERE ao.ActualDeliveryDate IS NOT NULL
  AND ao.ExpectedDate IS NOT NULL
GROUP BY
    ao.ShippingCarrier,
    ao.ShippingService
ORDER BY
    OnTimePercentage DESC,
    AverageShippingCost ASC,
    ao.ShippingCarrier;

-- Expected output (initial populated database, before updates; verified in Oracle Omega):
-- ShippingCarrier | ShippingService | TotalOrders | CustomersServed | AvgShippingCost | AvgWeight | AvgDeliveryDays | OnTime | Late | OnTime%
-- FedEx           | Standard        | 15          | 15              | 7.79            | 1.32      | 4.00            | 15     | 0    | 100.00
-- UPS             | Ground          | 15          | 15              | 7.92            | 1.33      | 4.00            | 15     | 0    | 100.00
-- USPS            | Express         | 15          | 15              | 8.19            | 1.43      | 4.00            | 15     | 0    | 100.00
-- 3 rows selected.

-- ============================================================
-- Query 11: Product profitability analysis.
--
-- English:
-- Identify the ten products generating the highest estimated
-- gross profit. Display cost-covered units sold, gross sales,
-- discounts, net sales, estimated acquisition costs,
-- estimated gross profit, and gross profit margin.
--
-- Acquisition cost uses weighted average unit cost from
-- received purchase orders for each product variant.
--
-- IMPORTANT:
-- Only sales with matching received-purchase cost records
-- are included in this profitability analysis.
--
-- Estimated Gross Profit = Net Sales - Acquisition Cost
-- ============================================================

PROMPT
PROMPT ===== QUERY 11: PRODUCT PROFITABILITY ANALYSIS =====

COLUMN ProductName FORMAT A25
COLUMN Brand FORMAT A20
COLUMN UnitsSold FORMAT 999,990
COLUMN GrossSales FORMAT 999,999,990.00
COLUMN Discounts FORMAT 999,990.00
COLUMN NetSales FORMAT 999,999,990.00
COLUMN AcquisitionCost FORMAT 999,999,990.00
COLUMN EstimatedGrossProfit FORMAT 999,999,990.00
COLUMN GrossProfitMargin FORMAT 990.00

WITH VariantCost AS (
    SELECT
        pod.VariantID,
        SUM(pod.OrderedQuantity * pod.CostPerUnit)
        / SUM(pod.OrderedQuantity) AS AverageUnitCost
    FROM F26_S001_T5_PURCHASE_ORDER_DETAIL pod
    JOIN F26_S001_T5_PURCHASE_ORDER po
        ON pod.PurchaseOrderID = po.PurchaseOrderID
    WHERE po.Status = 'Received'
    GROUP BY pod.VariantID
)

SELECT
    p.ProductName,
    p.Brand,
    SUM(oi.Quantity) AS UnitsSold,
    ROUND(
        SUM(oi.Quantity * oi.SellingPricePerUnit), 2
    ) AS GrossSales,
    ROUND(SUM(oi.Discount), 2) AS Discounts,
    ROUND(
        SUM(oi.Quantity * oi.SellingPricePerUnit)
        - SUM(oi.Discount), 2
    ) AS NetSales,
    ROUND(
        SUM(oi.Quantity * vc.AverageUnitCost), 2
    ) AS AcquisitionCost,
    ROUND(
        SUM(
            oi.Quantity *
            (oi.SellingPricePerUnit - vc.AverageUnitCost)
        ) - SUM(oi.Discount), 2
    ) AS EstimatedGrossProfit,
    ROUND(
        100 * (
            SUM(
                oi.Quantity *
                (oi.SellingPricePerUnit - vc.AverageUnitCost)
            ) - SUM(oi.Discount)
        ) / NULLIF(
            SUM(oi.Quantity * oi.SellingPricePerUnit)
            - SUM(oi.Discount), 0
        ), 2
    ) AS GrossProfitMargin
FROM F26_S001_T5_PRODUCT p
JOIN F26_S001_T5_PRODUCT_VARIANT pv
    ON p.ProductID = pv.ProductID
JOIN F26_S001_T5_ORDER_ITEM oi
    ON pv.VariantID = oi.VariantID
JOIN VariantCost vc
    ON pv.VariantID = vc.VariantID
GROUP BY
    p.ProductID,
    p.ProductName,
    p.Brand
ORDER BY
    EstimatedGrossProfit DESC,
    p.ProductName
FETCH FIRST 10 ROWS ONLY;

-- Expected output (initial populated database, before updates; verified in Oracle Omega):
-- ProductName                 | Brand              | UnitsSold | GrossSales | Discounts | NetSales | AcquisitionCost | EstimatedGrossProfit | GrossProfitMargin
-- Puffer Winter Jacket        | The North Face     | 3         | 485.97     | 0.00      | 485.97   | 67.50           | 418.47               | 86.11
-- Cashmere Blend Sweater      | Lands' End         | 3         | 296.97     | 0.00      | 296.97   | 67.50           | 229.47               | 77.27
-- Lightweight Windbreaker     | Columbia           | 2         | 134.98     | 0.00      | 134.98   | 40.00           | 94.98                | 70.37
-- Corduroy Trousers           | Amazon Essentials  | 3         | 126.87     | 0.00      | 126.87   | 45.00           | 81.87                | 64.53
-- Knit Sweater Dress          | ANRABESS           | 2         | 98.98      | 0.00      | 98.98    | 25.00           | 73.98                | 74.74
-- Formal Wrap Dress           | Calvin Klein      | 1         | 80.99      | 0.00      | 80.99    | 10.00           | 70.99                | 87.65
-- Cotton Pajama Set           | Amazon Essentials  | 3         | 105.27     | 0.00      | 105.27   | 45.00           | 60.27                | 57.25
-- Classic Denim Jacket        | Levi's             | 1         | 80.99      | 0.00      | 80.99    | 25.00           | 55.99                | 69.13
-- Slim Fit Oxford Shirt       | Goodthreads        | 3         | 94.47      | 0.00      | 94.47    | 45.00           | 49.47                | 52.37
-- Slim Fit Chinos             | Dockers            | 2         | 89.98      | 0.00      | 89.98    | 55.00           | 34.98                | 38.88
-- 10 rows selected.