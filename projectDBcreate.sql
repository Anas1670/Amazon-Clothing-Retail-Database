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
