SET SQLBLANKLINES ON

-- 1. PRODUCT
-- No foreign keys.

CREATE TABLE F26_S001_T5_PRODUCT (
    ProductID       NUMBER(10),
    ProductName     VARCHAR2(100) NOT NULL,
    Brand           VARCHAR2(100) NOT NULL,
    MSRP            NUMBER(10,2) NOT NULL,
    Description     VARCHAR2(500),
    Category        VARCHAR2(50) NOT NULL,
    SubCategory     VARCHAR2(50),

    CONSTRAINT F26_S001_T5_PRODUCT_PK
        PRIMARY KEY (ProductID),

    CONSTRAINT F26_S001_T5_PRODUCT_MSRP_CK
        CHECK (MSRP >= 0)
);

-- 2. PRODUCT_MATERIAL
-- Has ProductID as foreign key from PRODUCT.

CREATE TABLE F26_S001_T5_PRODUCT_MATERIAL (
    ProductID   NUMBER(10),
    Material    VARCHAR2(100),
    Percentage  NUMBER(5,2) NOT NULL,

    CONSTRAINT F26_S001_T5_PM_PK
        PRIMARY KEY (ProductID, Material),

    CONSTRAINT F26_S001_T5_PM_PRODUCT_FK
        FOREIGN KEY (ProductID)
        REFERENCES F26_S001_T5_PRODUCT (ProductID),

    CONSTRAINT F26_S001_T5_PM_PERCENT_CK
        CHECK (Percentage > 0 AND Percentage <= 100)
);

-- 3. SUPPLIER
-- No foreign keys.

CREATE TABLE F26_S001_T5_SUPPLIER (
    SupplierID           NUMBER(10),
    SupplierName         VARCHAR2(150) NOT NULL,
    ContactPerson        VARCHAR2(150),
    Phone                VARCHAR2(25),
    Email                VARCHAR2(254),
    CreditLimit          NUMBER(12,2),
    Net30Status          VARCHAR2(20) NOT NULL,
    SavingsPercentage    NUMBER(5,2),
    PaymentTerms         VARCHAR2(100),
    StandardLeadTime     NUMBER(5),
    MinimumOrderQuantity NUMBER(10),
    Street               VARCHAR2(200),
    City                 VARCHAR2(100),
    State                VARCHAR2(2),
    ZIPCode              VARCHAR2(10),

    CONSTRAINT F26_S001_T5_SUPPLIER_PK
        PRIMARY KEY (SupplierID),

    CONSTRAINT F26_S001_T5_SUP_CREDIT_CK
        CHECK (CreditLimit >= 0),

    CONSTRAINT F26_S001_T5_SUP_NET30_CK
        CHECK (Net30Status IN ('Active', 'Inactive')),

    CONSTRAINT F26_S001_T5_SUP_SAVINGS_CK
        CHECK (SavingsPercentage BETWEEN 0 AND 100),

    CONSTRAINT F26_S001_T5_SUP_LEAD_CK
        CHECK (StandardLeadTime >= 0),

    CONSTRAINT F26_S001_T5_SUP_MOQ_CK
        CHECK (MinimumOrderQuantity > 0)
);

-- 4. PRODUCT_VARIANT
-- Has ProductID as foreign key from PRODUCT and SupplierID from SUPPLIER.

CREATE TABLE F26_S001_T5_PRODUCT_VARIANT (
    VariantID     NUMBER(10),
    ASIN          VARCHAR2(10) NOT NULL,
    ProductID     NUMBER(10) NOT NULL,
    SupplierID    NUMBER(10) NOT NULL,
    VariantSize   VARCHAR2(30) NOT NULL,
    Color         VARCHAR2(50) NOT NULL,
    SellingPrice  NUMBER(10,2) NOT NULL,

    CONSTRAINT F26_S001_T5_PV_PK
        PRIMARY KEY (VariantID),

    CONSTRAINT F26_S001_T5_PV_ASIN_UQ
        UNIQUE (ASIN),

    CONSTRAINT F26_S001_T5_PV_PRODUCT_FK
        FOREIGN KEY (ProductID)
        REFERENCES F26_S001_T5_PRODUCT (ProductID),

    CONSTRAINT F26_S001_T5_PV_SUPPLIER_FK
        FOREIGN KEY (SupplierID)
        REFERENCES F26_S001_T5_SUPPLIER (SupplierID),

    CONSTRAINT F26_S001_T5_PV_PRICE_CK
        CHECK (SellingPrice >= 0)
);

-- 5. INVENTORY
-- Has VariantID as foreign key from PRODUCT_VARIANT.

CREATE TABLE F26_S001_T5_INVENTORY (
    InventoryID        NUMBER(10),
    VariantID          NUMBER(10) NOT NULL,
    PhysicalQuantity   NUMBER(10) DEFAULT 0 NOT NULL,
    AllocatedQuantity  NUMBER(10) DEFAULT 0 NOT NULL,
    ReorderThreshold   NUMBER(10) DEFAULT 0 NOT NULL,
    LastCountDate      DATE,

    CONSTRAINT F26_S001_T5_INV_PK
        PRIMARY KEY (InventoryID),

    CONSTRAINT F26_S001_T5_INV_VARIANT_UQ
        UNIQUE (VariantID),

    CONSTRAINT F26_S001_T5_INV_VARIANT_FK
        FOREIGN KEY (VariantID)
        REFERENCES F26_S001_T5_PRODUCT_VARIANT (VariantID),

    CONSTRAINT F26_S001_T5_INV_PHYSICAL_CK
        CHECK (PhysicalQuantity >= 0),

    CONSTRAINT F26_S001_T5_INV_ALLOC_CK
        CHECK (
            AllocatedQuantity >= 0
            AND AllocatedQuantity <= PhysicalQuantity
        ),

    CONSTRAINT F26_S001_T5_INV_REORDER_CK
        CHECK (ReorderThreshold >= 0)
);

-- 6. INVENTORY_LOCATION
-- Has InventoryID as foreign key from INVENTORY.

CREATE TABLE F26_S001_T5_INVENTORY_LOCATION (
    InventoryID  NUMBER(10),
    Aisle        VARCHAR2(20),
    Rack         VARCHAR2(20),
    Bin          VARCHAR2(20),

    CONSTRAINT F26_S001_T5_IL_PK
        PRIMARY KEY (InventoryID, Aisle, Rack, Bin),

    CONSTRAINT F26_S001_T5_IL_INVENTORY_FK
        FOREIGN KEY (InventoryID)
        REFERENCES F26_S001_T5_INVENTORY (InventoryID)
);

-- 7. PURCHASE_ORDER
-- Has SupplierID as foreign key from SUPPLIER.

-- Status values used by the project data:
-- Pending:  Order placed, not yet shipped.
-- Shipped:  Supplier dispatched the shipment.
-- Received: Entire purchase order arrived.

-- Implementation assumption: purchase orders are received in full.
-- Partial deliveries are not tracked.
-- Received represents a completed order in cost reports.

CREATE TABLE F26_S001_T5_PURCHASE_ORDER (
    PurchaseOrderID        NUMBER(10),
    SupplierID             NUMBER(10) NOT NULL,
    TotalCost              NUMBER(12,2) NOT NULL,
    TotalUnits             NUMBER(10) NOT NULL,
    Status                 VARCHAR2(30) NOT NULL,
    DateReceived           DATE,
    DatePlaced             DATE NOT NULL,
    EstimatedDeliveryDate  DATE,

    CONSTRAINT F26_S001_T5_PO_PK
        PRIMARY KEY (PurchaseOrderID),

    CONSTRAINT F26_S001_T5_PO_SUPPLIER_FK
        FOREIGN KEY (SupplierID)
        REFERENCES F26_S001_T5_SUPPLIER (SupplierID),

    CONSTRAINT F26_S001_T5_PO_COST_CK
        CHECK (TotalCost >= 0),

    CONSTRAINT F26_S001_T5_PO_UNITS_CK
        CHECK (TotalUnits > 0),

    CONSTRAINT F26_S001_T5_PO_RECEIVED_CK
        CHECK (DateReceived >= DatePlaced),

    CONSTRAINT F26_S001_T5_PO_EXPECTED_CK
        CHECK (EstimatedDeliveryDate >= DatePlaced),

    CONSTRAINT F26_S001_T5_PO_STATUS_CK
        CHECK (Status IN (
            'Pending',
            'Shipped',
            'Received'
        )),

    -- A received order must have a receipt date.
    -- All other statuses must have no receipt date.
    -- Update Status and DateReceived in the same UPDATE statement.
    CONSTRAINT F26_S001_T5_PO_STATUS_DATE_CK
        CHECK (
            (Status = 'Received' AND DateReceived IS NOT NULL)
            OR
            (Status <> 'Received' AND DateReceived IS NULL)
        )
);

-- 8. PURCHASE_ORDER_DETAIL
-- Has PurchaseOrdertID as foreign key from PURCHASE_ORDER and VariantID from VARIANT.

CREATE TABLE F26_S001_T5_PURCHASE_ORDER_DETAIL (
    PurchaseOrderID  NUMBER(10),
    VariantID        NUMBER(10),
    OrderedQuantity  NUMBER(10) NOT NULL,
    CostPerUnit      NUMBER(10,2) NOT NULL,
    Discount         NUMBER(12,2) DEFAULT 0 NOT NULL,

    CONSTRAINT F26_S001_T5_POD_PK
        PRIMARY KEY (PurchaseOrderID, VariantID),

    CONSTRAINT F26_S001_T5_POD_PO_FK
        FOREIGN KEY (PurchaseOrderID)
        REFERENCES F26_S001_T5_PURCHASE_ORDER (PurchaseOrderID),

    CONSTRAINT F26_S001_T5_POD_VARIANT_FK
        FOREIGN KEY (VariantID)
        REFERENCES F26_S001_T5_PRODUCT_VARIANT (VariantID),

    CONSTRAINT F26_S001_T5_POD_QTY_CK
        CHECK (OrderedQuantity > 0),

    CONSTRAINT F26_S001_T5_POD_COST_CK
        CHECK (CostPerUnit >= 0),

    CONSTRAINT F26_S001_T5_POD_DISCOUNT_CK
        CHECK (Discount >= 0)
);

-- 9. CUSTOMER
-- No foreign keys.

CREATE TABLE F26_S001_T5_CUSTOMER (
    CustomerID   NUMBER(10),
    Fname        VARCHAR2(100),
    Lname        VARCHAR2(100),
    Email        VARCHAR2(254),
    PhoneNumber  VARCHAR2(25),
    Street       VARCHAR2(200),
    City         VARCHAR2(100),
    State        VARCHAR2(2),
    ZIPCode      VARCHAR2(10),

    CONSTRAINT F26_S001_T5_CUSTOMER_PK
        PRIMARY KEY (CustomerID)
);

-- 10. AMAZON_ORDER
-- Has CustomerID as foreign key from CUSTOMER.

CREATE TABLE F26_S001_T5_AMAZON_ORDER (
    OrderNumber         NUMBER(10),
    CustomerID          NUMBER(10) NOT NULL,
    TrackingNumber      VARCHAR2(100),
    PackageWeight       NUMBER(10,3),
    OrderDate           DATE NOT NULL,
    ShippingDate        DATE,
    AmazonReferralCost  NUMBER(12,2),
    SubscriptionCost    NUMBER(12,2),
    ExpectedDate        DATE,
    ShippingService     VARCHAR2(20),
    ShippingCost        NUMBER(12,2),
    Width               NUMBER(10,2),
    Height              NUMBER(10,2),
    TotalSales          NUMBER(12,2) NOT NULL,
    DestinationRegion   VARCHAR2(100),
    ActualDeliveryDate  DATE,
    ShippingCarrier     VARCHAR2(20),

    CONSTRAINT F26_S001_T5_AO_PK
        PRIMARY KEY (OrderNumber),

    CONSTRAINT F26_S001_T5_AO_CUSTOMER_FK
        FOREIGN KEY (CustomerID)
        REFERENCES F26_S001_T5_CUSTOMER (CustomerID),

    CONSTRAINT F26_S001_T5_AO_CARRIER_CK
        CHECK (ShippingCarrier IN ('USPS', 'UPS', 'FedEx', 'DHL')),

    CONSTRAINT F26_S001_T5_AO_SERVICE_CK
        CHECK (ShippingService IN ('Ground', 'Priority', 'Express', 'Standard')),

    CONSTRAINT F26_S001_T5_AO_MONEY_CK
        CHECK (
            AmazonReferralCost >= 0
            AND SubscriptionCost >= 0
            AND ShippingCost >= 0
            AND TotalSales >= 0
        ),

    CONSTRAINT F26_S001_T5_AO_PACKAGE_CK
        CHECK (
            PackageWeight > 0
            AND Width > 0
            AND Height > 0
        ),

    CONSTRAINT F26_S001_T5_AO_SHIPDATE_CK
        CHECK (ShippingDate >= OrderDate),

    CONSTRAINT F26_S001_T5_AO_EXPECTED_CK
        CHECK (ExpectedDate >= OrderDate),

    CONSTRAINT F26_S001_T5_AO_DELIVERY_CK
        CHECK (
            ActualDeliveryDate IS NULL
            OR (
                ShippingDate IS NOT NULL
                AND ActualDeliveryDate >= ShippingDate
            )
        ),

    CONSTRAINT F26_S001_T5_AO_SHIPINFO_CK
        CHECK (
            ShippingDate IS NULL
            OR (
                ShippingCarrier IS NOT NULL
                AND ShippingService IS NOT NULL
                AND PackageWeight IS NOT NULL
                AND Width IS NOT NULL
                AND Height IS NOT NULL
                AND ShippingCost IS NOT NULL
                AND DestinationRegion IS NOT NULL
            )
        )
);

-- 11. ORDER_ITEM
-- Has OrderNumber as foreign key from AMAZON_ORDER and VariantID from PRODUCT_VARIANT.

CREATE TABLE F26_S001_T5_ORDER_ITEM (
    OrderNumber          NUMBER(10),
    LineItemNumber       NUMBER(10),
    VariantID            NUMBER(10) NOT NULL,
    Quantity             NUMBER(10) NOT NULL,
    SellingPricePerUnit  NUMBER(10,2) NOT NULL,
    Discount             NUMBER(12,2) DEFAULT 0 NOT NULL,

    CONSTRAINT F26_S001_T5_OI_PK
        PRIMARY KEY (OrderNumber, LineItemNumber),

    CONSTRAINT F26_S001_T5_OI_ORDER_FK
        FOREIGN KEY (OrderNumber)
        REFERENCES F26_S001_T5_AMAZON_ORDER (OrderNumber),

    CONSTRAINT F26_S001_T5_OI_VARIANT_FK
        FOREIGN KEY (VariantID)
        REFERENCES F26_S001_T5_PRODUCT_VARIANT (VariantID),

    CONSTRAINT F26_S001_T5_OI_LINE_CK
        CHECK (LineItemNumber > 0),

    CONSTRAINT F26_S001_T5_OI_QUANTITY_CK
        CHECK (Quantity > 0),

    CONSTRAINT F26_S001_T5_OI_PRICE_CK
        CHECK (SellingPricePerUnit >= 0),

    CONSTRAINT F26_S001_T5_OI_DISCOUNT_CK
        CHECK (Discount >= 0)
);

-- 12. RETURN
-- Has OrderNumber as foreign key from ORDER_ITEM.

CREATE TABLE F26_S001_T5_RETURN (
    ReturnNumber        NUMBER(10),
    OrderNumber         NUMBER(10) NOT NULL,
    LineItemNumber      NUMBER(10) NOT NULL,
    ReturnDate          DATE NOT NULL,
    Reason              VARCHAR2(500),
    RefundAmount        NUMBER(12,2) NOT NULL,
    RestockingFee       NUMBER(12,2) DEFAULT 0 NOT NULL,
    ReturnShippingCost  NUMBER(12,2) DEFAULT 0 NOT NULL,

    CONSTRAINT F26_S001_T5_RET_PK
        PRIMARY KEY (ReturnNumber),

    CONSTRAINT F26_S001_T5_RET_ITEM_UQ
        UNIQUE (OrderNumber, LineItemNumber),

    CONSTRAINT F26_S001_T5_RET_ITEM_FK
        FOREIGN KEY (OrderNumber, LineItemNumber)
        REFERENCES F26_S001_T5_ORDER_ITEM
            (OrderNumber, LineItemNumber),

    CONSTRAINT F26_S001_T5_RET_REFUND_CK
        CHECK (RefundAmount >= 0),

    CONSTRAINT F26_S001_T5_RET_RESTOCK_CK
        CHECK (RestockingFee >= 0),

    CONSTRAINT F26_S001_T5_RET_SHIPPING_CK
        CHECK (ReturnShippingCost >= 0)
);

-- 13. EMPLOYEE
-- Has SupervisorID as foreign key references another employee in this same table.

CREATE TABLE F26_S001_T5_EMPLOYEE (
    EmployeeID    NUMBER(10),
    Fname         VARCHAR2(100) NOT NULL,
    Lname         VARCHAR2(100) NOT NULL,
    Role          VARCHAR2(100),
    Salary        NUMBER(12,2) NOT NULL,
    HireDate      DATE NOT NULL,
    Department    VARCHAR2(100),
    SupervisorID  NUMBER(10),

    CONSTRAINT F26_S001_T5_EMP_PK
        PRIMARY KEY (EmployeeID),

    CONSTRAINT F26_S001_T5_EMP_SUPERVISOR_FK
        FOREIGN KEY (SupervisorID)
        REFERENCES F26_S001_T5_EMPLOYEE (EmployeeID),

    CONSTRAINT F26_S001_T5_EMP_SALARY_CK
        CHECK (Salary >= 0),

    CONSTRAINT F26_S001_T5_EMP_SELF_CK
        CHECK (SupervisorID <> EmployeeID)
);

-- 14. OPERATING_COST
-- No foreign keys.

CREATE TABLE F26_S001_T5_OPERATING_COST (
    ExpenseNumber  NUMBER(10),
    ExpenseDate    DATE NOT NULL,
    Category       VARCHAR2(100) NOT NULL,
    Description    VARCHAR2(500),
    PaymentMethod  VARCHAR2(50),
    Amount         NUMBER(12,2) NOT NULL,
    ExpenseType    VARCHAR2(20) NOT NULL,

    CONSTRAINT F26_S001_T5_OC_PK
        PRIMARY KEY (ExpenseNumber),

    CONSTRAINT F26_S001_T5_OC_AMOUNT_CK
        CHECK (Amount >= 0),

    CONSTRAINT F26_S001_T5_OC_TYPE_CK
        CHECK (ExpenseType IN ('Recurring', 'One-time'))
);







