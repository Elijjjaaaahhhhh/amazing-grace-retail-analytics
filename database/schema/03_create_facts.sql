USE AmazingGraceStore;
GO

CREATE TABLE dbo.FactLoans
(
    LoanID                  INT             NOT NULL IDENTITY(1,1),
    LoanDateKey             INT             NOT NULL,
    PrincipalAmount         DECIMAL(12,2)   NOT NULL,
    DurationMonths          INT             NOT NULL,
    MonthlyRepayment        DECIMAL(12,2)   NOT NULL,
    TotalRepayment          DECIMAL(12,2)   NOT NULL,
    InterestAmount          DECIMAL(12,2)   NOT NULL,
    EffectiveInterestRate   DECIMAL(5,2)    NOT NULL,
    IsFullyRepaid           BIT             NOT NULL DEFAULT(0),
    RepaidToDate            DECIMAL(12,2)   NOT NULL DEFAULT(0),
    RemainingBalance        DECIMAL(12,2)   NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_FactLoans PRIMARY KEY CLUSTERED (LoanID),
    CONSTRAINT FK_FactLoans_LoanDate 
        FOREIGN KEY (LoanDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT CK_FactLoans_PrincipalRange 
        CHECK (PrincipalAmount >= 2000000 AND PrincipalAmount <= 8000000),
    CONSTRAINT CK_FactLoans_Duration 
        CHECK (DurationMonths IN (6, 12)),
    CONSTRAINT CK_FactLoans_RepaidLogic 
        CHECK (RepaidToDate <= TotalRepayment),
    CONSTRAINT CK_FactLoans_PositiveAmounts 
        CHECK (PrincipalAmount > 0 AND TotalRepayment > 0 AND MonthlyRepayment > 0)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_FactLoans_LoanDateKey 
    ON dbo.FactLoans(LoanDateKey);

CREATE NONCLUSTERED INDEX IX_FactLoans_Status 
    ON dbo.FactLoans(IsFullyRepaid);
GO

PRINT 'Table FactLoans created successfully!';
GO

CREATE TABLE dbo.FactBells
(
    BellID              INT             NOT NULL IDENTITY(1,1),
    PurchaseDateKey     INT             NOT NULL,
    CategoryID          INT             NOT NULL,
    SubcategoryID       INT             NOT NULL,
    BellSizeID          INT             NOT NULL,
    BellCost            DECIMAL(12,2)   NOT NULL,
    TotalItems          INT             NOT NULL,
    SellableItems       INT             NOT NULL,
    UnsellableItems     INT             NOT NULL,
    SellablePercentage  DECIMAL(5,2)    NOT NULL,
    CostPerItem         DECIMAL(10,2)   NOT NULL,
    TransportCost       DECIMAL(10,2)   NOT NULL,
    LoanID              INT             NULL,
    IsProfitFunded      BIT             NOT NULL,
    TripID              INT             NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_FactBells PRIMARY KEY CLUSTERED (BellID),
    CONSTRAINT FK_FactBells_PurchaseDate 
        FOREIGN KEY (PurchaseDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactBells_Category 
        FOREIGN KEY (CategoryID) REFERENCES dbo.DimCategories(CategoryID),
    CONSTRAINT FK_FactBells_Subcategory 
        FOREIGN KEY (SubcategoryID) REFERENCES dbo.DimSubcategories(SubcategoryID),
    CONSTRAINT FK_FactBells_BellSize 
        FOREIGN KEY (BellSizeID) REFERENCES dbo.DimBellSizes(BellSizeID),
    CONSTRAINT FK_FactBells_Loan 
        FOREIGN KEY (LoanID) REFERENCES dbo.FactLoans(LoanID),
    CONSTRAINT CK_FactBells_CostRange 
        CHECK (BellCost >= 350000 AND BellCost <= 850000),
    CONSTRAINT CK_FactBells_ItemLogic 
        CHECK (TotalItems = SellableItems + UnsellableItems),
    CONSTRAINT CK_FactBells_PositiveItems 
        CHECK (TotalItems > 0 AND SellableItems > 0)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_FactBells_PurchaseDateKey 
    ON dbo.FactBells(PurchaseDateKey);

CREATE NONCLUSTERED INDEX IX_FactBells_CategoryID 
    ON dbo.FactBells(CategoryID);

CREATE NONCLUSTERED INDEX IX_FactBells_SubcategoryID 
    ON dbo.FactBells(SubcategoryID);

CREATE NONCLUSTERED INDEX IX_FactBells_LoanID 
    ON dbo.FactBells(LoanID) 
    WHERE LoanID IS NOT NULL;

CREATE NONCLUSTERED INDEX IX_FactBells_TripID 
    ON dbo.FactBells(TripID);
GO

PRINT 'Table FactBells created successfully!';
GO

CREATE TABLE dbo.FactSales
(
    SaleTransactionID   BIGINT          NOT NULL IDENTITY(1,1),
    SaleDateKey         INT             NOT NULL,
    SaleDateTime        DATETIME        NOT NULL,
    TotalItems          INT             NOT NULL,
    SubtotalAmount      DECIMAL(12,2)   NOT NULL,
    DiscountAmount      DECIMAL(12,2)   NOT NULL DEFAULT(0),
    TotalAmount         DECIMAL(12,2)   NOT NULL,
    PaymentMethod       NVARCHAR(20)    NOT NULL,
    IsRecurringCustomer BIT             NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_FactSales PRIMARY KEY CLUSTERED (SaleTransactionID),
    CONSTRAINT FK_FactSales_SaleDate 
        FOREIGN KEY (SaleDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT CK_FactSales_TotalLogic 
        CHECK (TotalAmount = SubtotalAmount - DiscountAmount),
    CONSTRAINT CK_FactSales_PositiveAmounts 
        CHECK (SubtotalAmount > 0 AND TotalAmount > 0),
    CONSTRAINT CK_FactSales_PaymentMethod 
        CHECK (PaymentMethod IN ('Cash', 'Transfer', 'POS'))
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_FactSales_SaleDateKey 
    ON dbo.FactSales(SaleDateKey);

CREATE NONCLUSTERED INDEX IX_FactSales_SaleDateTime 
    ON dbo.FactSales(SaleDateTime);

CREATE NONCLUSTERED INDEX IX_FactSales_PaymentMethod 
    ON dbo.FactSales(PaymentMethod);
GO

PRINT 'Table FactSales created successfully!';
GO

CREATE TABLE dbo.FactItems
(
    ItemID                BIGINT          NOT NULL IDENTITY(1,1),
    BellID                INT             NOT NULL,
    CategoryID            INT             NOT NULL,
    SubcategoryID         INT             NOT NULL,
    GradeID               INT             NOT NULL,
    CostPerItem           DECIMAL(10,2)   NOT NULL,
    BasePrice             DECIMAL(10,2)   NOT NULL,
    IsTopTier             BIT             NOT NULL,
    ActualMarkupPercent   DECIMAL(5,2)    NOT NULL,
    SellingPrice          DECIMAL(10,2)   NOT NULL,
    DateAddedKey          INT             NOT NULL,
    DateSoldKey           INT             NULL,
    DaysInInventory       INT             NULL,
    IsSold                BIT             NOT NULL DEFAULT(0),
    IsInDiscount          BIT             NOT NULL DEFAULT(0),
    DiscountPercent       DECIMAL(5,2)    NULL,
    DiscountedPrice       DECIMAL(10,2)   NULL,
    FinalSalePrice        DECIMAL(10,2)   NULL,
    SaleTransactionID     BIGINT          NULL,
    
    -- Constraints
    CONSTRAINT PK_FactItems PRIMARY KEY CLUSTERED (ItemID),
    CONSTRAINT FK_FactItems_Bell 
        FOREIGN KEY (BellID) REFERENCES dbo.FactBells(BellID),
    CONSTRAINT FK_FactItems_Category 
        FOREIGN KEY (CategoryID) REFERENCES dbo.DimCategories(CategoryID),
    CONSTRAINT FK_FactItems_Subcategory 
        FOREIGN KEY (SubcategoryID) REFERENCES dbo.DimSubcategories(SubcategoryID),
    CONSTRAINT FK_FactItems_Grade 
        FOREIGN KEY (GradeID) REFERENCES dbo.DimItemGrades(GradeID),
    CONSTRAINT FK_FactItems_DateAdded 
        FOREIGN KEY (DateAddedKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactItems_DateSold 
        FOREIGN KEY (DateSoldKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT FK_FactItems_SaleTransaction 
        FOREIGN KEY (SaleTransactionID) REFERENCES dbo.FactSales(SaleTransactionID),
    CONSTRAINT CK_FactItems_MarkupRange 
        CHECK (ActualMarkupPercent >= 20 AND ActualMarkupPercent <= 50),
    CONSTRAINT CK_FactItems_DiscountRange 
        CHECK (DiscountPercent IS NULL OR DiscountPercent IN (25, 40, 50)),
    CONSTRAINT CK_FactItems_SoldLogic 
        CHECK (
            (IsSold = 0 AND DateSoldKey IS NULL AND SaleTransactionID IS NULL) OR
            (IsSold = 1 AND DateSoldKey IS NOT NULL AND SaleTransactionID IS NOT NULL)
        ),
    CONSTRAINT CK_FactItems_PositivePrices 
        CHECK (CostPerItem > 0 AND SellingPrice > 0)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_FactItems_BellID 
    ON dbo.FactItems(BellID);

CREATE NONCLUSTERED INDEX IX_FactItems_CategoryID 
    ON dbo.FactItems(CategoryID);

CREATE NONCLUSTERED INDEX IX_FactItems_SubcategoryID 
    ON dbo.FactItems(SubcategoryID);

CREATE NONCLUSTERED INDEX IX_FactItems_DateAddedKey 
    ON dbo.FactItems(DateAddedKey);

CREATE NONCLUSTERED INDEX IX_FactItems_DateSoldKey 
    ON dbo.FactItems(DateSoldKey) 
    WHERE DateSoldKey IS NOT NULL;

CREATE NONCLUSTERED INDEX IX_FactItems_IsSold 
    ON dbo.FactItems(IsSold);

CREATE NONCLUSTERED INDEX IX_FactItems_SaleTransactionID 
    ON dbo.FactItems(SaleTransactionID) 
    WHERE SaleTransactionID IS NOT NULL;

CREATE NONCLUSTERED INDEX IX_FactItems_IsTopTier 
    ON dbo.FactItems(IsTopTier) 
    WHERE IsTopTier = 1;
GO

PRINT 'Table FactItems created successfully!';
GO

CREATE TABLE dbo.FactLoanRepayments
(
    RepaymentID      INT             NOT NULL IDENTITY(1,1),
    LoanID           INT             NOT NULL,
    RepaymentDateKey INT             NOT NULL,
    ScheduledAmount  DECIMAL(12,2)   NOT NULL,
    ActualAmount     DECIMAL(12,2)   NOT NULL,
    PaymentStatus    NVARCHAR(20)    NOT NULL,
    DaysLate         INT             NULL,
    
    -- Constraints
    CONSTRAINT PK_FactLoanRepayments PRIMARY KEY CLUSTERED (RepaymentID),
    CONSTRAINT FK_FactLoanRepayments_Loan 
        FOREIGN KEY (LoanID) REFERENCES dbo.FactLoans(LoanID),
    CONSTRAINT FK_FactLoanRepayments_RepaymentDate 
        FOREIGN KEY (RepaymentDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT CK_FactLoanRepayments_PaymentStatus 
        CHECK (PaymentStatus IN ('OnTime', 'Late', 'Partial')),
    CONSTRAINT CK_FactLoanRepayments_PositiveAmounts 
        CHECK (ScheduledAmount > 0 AND ActualAmount >= 0),
    CONSTRAINT CK_FactLoanRepayments_LateLogic 
        CHECK (
            (PaymentStatus = 'OnTime' AND DaysLate IS NULL) OR
            (PaymentStatus IN ('Late', 'Partial') AND DaysLate IS NOT NULL)
        )
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_FactLoanRepayments_LoanID 
    ON dbo.FactLoanRepayments(LoanID);

CREATE NONCLUSTERED INDEX IX_FactLoanRepayments_RepaymentDateKey 
    ON dbo.FactLoanRepayments(RepaymentDateKey);

CREATE NONCLUSTERED INDEX IX_FactLoanRepayments_Status 
    ON dbo.FactLoanRepayments(PaymentStatus);
GO

PRINT 'Table FactLoanRepayments created successfully!';
GO


CREATE TABLE dbo.FactExpenses
(
    ExpenseID          INT             NOT NULL IDENTITY(1,1),
    ExpenseDateKey     INT             NOT NULL,
    ExpenseCategory    NVARCHAR(50)    NOT NULL,
    ExpenseDescription NVARCHAR(200)   NULL,
    Amount             DECIMAL(12,2)   NOT NULL,
    IsRecurring        BIT             NOT NULL,
    PaymentMethod      NVARCHAR(20)    NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_FactExpenses PRIMARY KEY CLUSTERED (ExpenseID),
    CONSTRAINT FK_FactExpenses_ExpenseDate 
        FOREIGN KEY (ExpenseDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT CK_FactExpenses_Category 
        CHECK (ExpenseCategory IN ('Rent', 'Staff', 'Utilities', 'Transport', 'Other')),
    CONSTRAINT CK_FactExpenses_PaymentMethod 
        CHECK (PaymentMethod IN ('Cash', 'Transfer')),
    CONSTRAINT CK_FactExpenses_PositiveAmount 
        CHECK (Amount > 0)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_FactExpenses_ExpenseDateKey 
    ON dbo.FactExpenses(ExpenseDateKey);

CREATE NONCLUSTERED INDEX IX_FactExpenses_Category 
    ON dbo.FactExpenses(ExpenseCategory);

CREATE NONCLUSTERED INDEX IX_FactExpenses_IsRecurring 
    ON dbo.FactExpenses(IsRecurring);
GO

PRINT 'Table FactExpenses created successfully!';
GO


CREATE TABLE dbo.FactCashMovements
(
    CashMovementID     INT             NOT NULL IDENTITY(1,1),
    MovementDateKey    INT             NOT NULL,
    AccountType        NVARCHAR(20)    NOT NULL,
    MovementType       NVARCHAR(20)    NOT NULL,
    Amount             DECIMAL(12,2)   NOT NULL,
    SourceAccount      NVARCHAR(20)    NULL,
    DestinationAccount NVARCHAR(20)    NULL,
    Description        NVARCHAR(200)   NULL,
    RunningBalance     DECIMAL(12,2)   NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_FactCashMovements PRIMARY KEY CLUSTERED (CashMovementID),
    CONSTRAINT FK_FactCashMovements_MovementDate 
        FOREIGN KEY (MovementDateKey) REFERENCES dbo.DimDate(DateKey),
    CONSTRAINT CK_FactCashMovements_AccountType 
        CHECK (AccountType IN ('Profits', 'Operations', 'Debts')),
    CONSTRAINT CK_FactCashMovements_MovementType 
        CHECK (MovementType IN ('Deposit', 'Withdrawal', 'Transfer')),
    CONSTRAINT CK_FactCashMovements_TransferLogic 
        CHECK (
            (MovementType = 'Transfer' AND SourceAccount IS NOT NULL AND DestinationAccount IS NOT NULL) OR
            (MovementType IN ('Deposit', 'Withdrawal') AND SourceAccount IS NULL AND DestinationAccount IS NULL)
        ),
    CONSTRAINT CK_FactCashMovements_PositiveAmount 
        CHECK (Amount > 0)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_FactCashMovements_MovementDateKey 
    ON dbo.FactCashMovements(MovementDateKey);

CREATE NONCLUSTERED INDEX IX_FactCashMovements_AccountType 
    ON dbo.FactCashMovements(AccountType);

CREATE NONCLUSTERED INDEX IX_FactCashMovements_MovementType 
    ON dbo.FactCashMovements(MovementType);
GO

PRINT 'Table FactCashMovements created successfully!';
GO