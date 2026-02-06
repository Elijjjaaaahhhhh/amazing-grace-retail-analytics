USE AmazingGraceStore;
GO

-- FactLoans Generation --
-- Create temp table for loan generation parameters
CREATE TABLE #LoanSeed (
    LoanNumber INT,
    SeedValue INT,
    LoanMonth INT,
    LoanDay INT
);

-- Insert seed data for reproducibility (seed = 42 base)
INSERT INTO #LoanSeed (LoanNumber, SeedValue, LoanMonth, LoanDay)
VALUES
    (1, 42,  1,  8),   -- Jan loan
    (2, 43,  2, 20),   -- Feb loan
    (3, 44,  4, 15),   -- Apr loan
    (4, 45,  5, 28),   -- May loan
    (5, 46,  7, 10),   -- Jul loan
    (6, 47,  8, 22),   -- Aug loan
    (7, 48, 10,  5),   -- Oct loan
    (8, 49, 11, 18);   -- Nov loan

-- Generate loans with controlled randomization
INSERT INTO dbo.FactLoans
(
    LoanDateKey,
    PrincipalAmount,
    DurationMonths,
    MonthlyRepayment,
    TotalRepayment,
    InterestAmount,
    EffectiveInterestRate,
    IsFullyRepaid,
    RepaidToDate,
    RemainingBalance
)
SELECT
    CAST(FORMAT(DATEFROMPARTS(2024, ls.LoanMonth, ls.LoanDay), 'yyyyMMdd') AS INT) AS LoanDateKey,
    
    -- Principal: ₦2M-₦8M in ₦500K increments
    CAST(
        ROUND(
            (2000000 + (ABS(CHECKSUM(NEWID()) % 13) * 500000)),
            0
        ) AS DECIMAL(12,2)
    ) AS PrincipalAmount,
    
    -- Duration: 6 or 12 months
    CASE WHEN (ABS(CHECKSUM(NEWID()) % 2) = 0) THEN 6 ELSE 12 END AS DurationMonths,
    
    -- Monthly payment calculated below
    0 AS MonthlyRepayment,  -- Placeholder
    0 AS TotalRepayment,    -- Placeholder
    0 AS InterestAmount,    -- Placeholder
    0.00 AS EffectiveInterestRate,  -- Placeholder
    0 AS IsFullyRepaid,
    0.00 AS RepaidToDate,
    0 AS RemainingBalance
FROM #LoanSeed ls;

-- Update calculated fields
UPDATE dbo.FactLoans
SET 
    -- Interest rate varies: 12%-18% annual
    EffectiveInterestRate = 
        CAST(
            (12.0 + (ABS(CHECKSUM(NEWID()) % 7)))  -- 12-18%
            AS DECIMAL(5,2)
        ),
    
    -- Total repayment = Principal × (1 + (Rate × Duration/12))
    TotalRepayment = 
        CAST(
            PrincipalAmount * 
            (1 + ((12.0 + (LoanID % 7)) / 100.0) * (DurationMonths / 12.0))
            AS DECIMAL(12,2)
        );

-- Calculate monthly repayment
UPDATE dbo.FactLoans
SET 
    MonthlyRepayment = CAST(TotalRepayment / DurationMonths AS DECIMAL(12,2)),
    InterestAmount = TotalRepayment - PrincipalAmount,
    RemainingBalance = TotalRepayment;

-- Verify generation
SELECT 
    LoanID,
    CONVERT(DATE, CAST(LoanDateKey AS VARCHAR(8)), 112) AS LoanDate,
    FORMAT(PrincipalAmount, 'C', 'en-NG') AS Principal,
    DurationMonths,
    FORMAT(MonthlyRepayment, 'C', 'en-NG') AS MonthlyPayment,
    FORMAT(TotalRepayment, 'C', 'en-NG') AS TotalToRepay,
    FORMAT(InterestAmount, 'C', 'en-NG') AS Interest,
    CAST(EffectiveInterestRate AS VARCHAR(10)) + '%' AS AnnualRate
FROM dbo.FactLoans
ORDER BY LoanDateKey;

-- Summary statistics
SELECT 
    COUNT(*) AS TotalLoans,
    FORMAT(AVG(PrincipalAmount), 'C', 'en-NG') AS AvgPrincipal,
    FORMAT(SUM(PrincipalAmount), 'C', 'en-NG') AS TotalPrincipal,
    FORMAT(SUM(InterestAmount), 'C', 'en-NG') AS TotalInterest,
    AVG(DurationMonths) AS AvgDuration,
    AVG(EffectiveInterestRate) AS AvgInterestRate
FROM dbo.FactLoans;

-- Cleanup
DROP TABLE #LoanSeed;

PRINT 'FactLoans populated: 8 loans generated';
GO



--FactLoanRepayments Generation--
-- Create sequence of repayment months for each loan
;WITH RepaymentSchedule AS (
    SELECT 
        l.LoanID,
        l.LoanDateKey,
        l.DurationMonths,
        l.MonthlyRepayment,
        n.Number AS RepaymentMonth
    FROM dbo.FactLoans l
    CROSS JOIN (
        SELECT 1 AS Number UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL
        SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL
        SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL
        SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
    ) n
    WHERE n.Number <= l.DurationMonths
)
INSERT INTO dbo.FactLoanRepayments
(
    LoanID,
    RepaymentDateKey,
    ScheduledAmount,
    ActualAmount,
    PaymentStatus,
    DaysLate
)
SELECT
    rs.LoanID,
    
    -- Repayment date = Loan date + N months
    CAST(
        FORMAT(
            DATEADD(MONTH, rs.RepaymentMonth, 
                CAST(CAST(rs.LoanDateKey AS VARCHAR(8)) AS DATE)
            ),
            'yyyyMMdd'
        ) AS INT
    ) AS RepaymentDateKey,
    
    rs.MonthlyRepayment AS ScheduledAmount,
    
    -- Actual amount varies for partial payments
    CASE 
        WHEN (ABS(CHECKSUM(NEWID()) % 100) < 3) THEN  -- 3% Partial
            CAST(rs.MonthlyRepayment * (0.80 + (ABS(CHECKSUM(NEWID()) % 16) / 100.0)) AS DECIMAL(12,2))
        ELSE 
            rs.MonthlyRepayment  -- Full payment
    END AS ActualAmount,
    
    -- Payment status distribution
    CASE 
        WHEN (ABS(CHECKSUM(NEWID()) % 100) < 90) THEN 'OnTime'   -- 90%
        WHEN (ABS(CHECKSUM(NEWID()) % 100) < 97) THEN 'Late'     -- 7%
        ELSE 'Partial'  -- 3%
    END AS PaymentStatus,
    
    -- Days late (1-5 days if late)
    CASE 
        WHEN (ABS(CHECKSUM(NEWID()) % 100) >= 90) AND (ABS(CHECKSUM(NEWID()) % 100) < 97) 
        THEN ABS(CHECKSUM(NEWID()) % 5) + 1
        ELSE NULL
    END AS DaysLate
FROM RepaymentSchedule rs;
GO

-- Update partial payments to match status
UPDATE dbo.FactLoanRepayments
SET PaymentStatus = 'Partial'
WHERE ActualAmount < ScheduledAmount;

-- Update days late for partial payments
UPDATE dbo.FactLoanRepayments
SET DaysLate = ABS(CHECKSUM(NEWID()) % 5) + 1
WHERE PaymentStatus IN ('Late', 'Partial') AND DaysLate IS NULL;

-- Verify generation
SELECT TOP 20
    r.RepaymentID,
    r.LoanID,
    CONVERT(DATE, CAST(r.RepaymentDateKey AS VARCHAR(8)), 112) AS RepaymentDate,
    FORMAT(r.ScheduledAmount, 'C', 'en-NG') AS Scheduled,
    FORMAT(r.ActualAmount, 'C', 'en-NG') AS Actual,
    r.PaymentStatus,
    r.DaysLate
FROM dbo.FactLoanRepayments r
ORDER BY r.LoanID, r.RepaymentDateKey;

-- Summary by status
SELECT 
    PaymentStatus,
    COUNT(*) AS Count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage,
    FORMAT(AVG(ActualAmount), 'C', 'en-NG') AS AvgAmount
FROM dbo.FactLoanRepayments
GROUP BY PaymentStatus
ORDER BY PaymentStatus;

-- Verify loan completion
SELECT 
    l.LoanID,
    l.DurationMonths,
    COUNT(r.RepaymentID) AS ActualRepayments,
    FORMAT(l.TotalRepayment, 'C', 'en-NG') AS TotalDue,
    FORMAT(SUM(r.ActualAmount), 'C', 'en-NG') AS TotalPaid,
    FORMAT(l.TotalRepayment - SUM(r.ActualAmount), 'C', 'en-NG') AS Shortfall
FROM dbo.FactLoans l
LEFT JOIN dbo.FactLoanRepayments r ON r.LoanID = l.LoanID
GROUP BY l.LoanID, l.DurationMonths, l.TotalRepayment
ORDER BY l.LoanID;

PRINT 'FactLoanRepayments populated: ~70 repayment records generated';
GO


-- HELPER FUNCTION: Weighted Random Category Selection

CREATE OR ALTER FUNCTION dbo.fn_GetWeightedCategory(@RandomValue FLOAT)
RETURNS INT
AS
BEGIN
    DECLARE @CategoryID INT;
    
    -- Distribution: Tops=25%, Bottoms=30%, Outerwear=15%, Activewear=20%, Dresses=10%
    SELECT @CategoryID = 
        CASE 
            WHEN @RandomValue < 0.25 THEN 1  -- Tops: 0-24.99%
            WHEN @RandomValue < 0.55 THEN 2  -- Bottoms: 25-54.99%
            WHEN @RandomValue < 0.70 THEN 3  -- Outerwear: 55-69.99%
            WHEN @RandomValue < 0.90 THEN 4  -- Activewear: 70-89.99%
            ELSE 5                            -- Dresses: 90-100%
        END;
    
    RETURN @CategoryID;
END;
GO

PRINT 'Helper function fn_GetWeightedCategory created';
GO

CREATE OR ALTER FUNCTION dbo.fn_GetWeightedBellSize(@RandomValue FLOAT)
RETURNS INT
AS
BEGIN
    DECLARE @BellSizeID INT;
    
    -- Distribution: Small=25%, Medium=45%, Large=30%
    SELECT @BellSizeID = 
        CASE 
            WHEN @RandomValue < 0.25 THEN 1  -- Small: 0-24.99%
            WHEN @RandomValue < 0.70 THEN 2  -- Medium: 25-69.99%
            ELSE 3                            -- Large: 70-100%
        END;
    
    RETURN @BellSizeID;
END;
GO

PRINT 'Helper function fn_GetWeightedBellSize created';
GO


--FactBell Generation--
-- PART 1: LOAN-FUNDED BELLS


CREATE TABLE #LoanBellSchedule (
    TripID INT,
    LoanID INT,
    BellsInTrip INT,
    PurchaseDate DATE
);

INSERT INTO #LoanBellSchedule (TripID, LoanID, BellsInTrip, PurchaseDate)
SELECT 
    ROW_NUMBER() OVER (ORDER BY LoanDateKey) AS TripID,
    LoanID,
    8 + (ABS(CHECKSUM(NEWID())) % 5) AS BellsInTrip,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 5, 
        CAST(CAST(LoanDateKey AS VARCHAR(8)) AS DATE)
    ) AS PurchaseDate
FROM dbo.FactLoans;

-- Validate dates against DimDate
UPDATE lbs
SET PurchaseDate = (
    SELECT MIN(d.FullDate)
    FROM dbo.DimDate d
    WHERE d.FullDate >= lbs.PurchaseDate
      AND d.IsStoreOpen = 1
)
FROM #LoanBellSchedule lbs
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DimDate 
    WHERE FullDate = lbs.PurchaseDate AND IsStoreOpen = 1
);

PRINT 'Loan schedule created and validated';
GO

-- Create temp table with ALL calculated fields BEFORE insert
CREATE TABLE #LoanBells (
    TripID INT,
    LoanID INT,
    PurchaseDate DATE,
    BellsInTrip INT,
    CategoryID INT,
    SubcategoryID INT,
    BellSizeID INT,
    TotalItems INT,
    SellablePercentage DECIMAL(5,2),
    SellableItems INT,
    UnsellableItems INT,
    BellCost DECIMAL(12,2),
    CostPerItem DECIMAL(10,2),
    TransportCost DECIMAL(10,2)
);

-- Generate bell details with weighted distributions
;WITH BellNumbers AS (
    SELECT 
        lbs.TripID,
        lbs.LoanID,
        lbs.PurchaseDate,
        lbs.BellsInTrip,
        n.Number AS BellNumberInTrip
    FROM #LoanBellSchedule lbs
    CROSS JOIN (
        SELECT 1 AS Number UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL
        SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL
        SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL
        SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
    ) AS n(Number)
    WHERE n.Number <= lbs.BellsInTrip
),
BellsWithDistributions AS (
    SELECT 
        bn.*,
        -- Weighted CategoryID
        CASE 
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 25 THEN 1
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 55 THEN 2
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 3
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 90 THEN 4
            ELSE 5
        END AS CategoryID,
        -- Weighted BellSizeID
        CASE 
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 25 THEN 1
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 2
            ELSE 3
        END AS BellSizeID
    FROM BellNumbers bn
)
INSERT INTO #LoanBells (
    TripID, LoanID, PurchaseDate, BellsInTrip, 
    CategoryID, SubcategoryID, BellSizeID,
    TotalItems, SellablePercentage, SellableItems, UnsellableItems,
    BellCost, CostPerItem, TransportCost
)
SELECT 
    bwd.TripID,
    bwd.LoanID,
    bwd.PurchaseDate,
    bwd.BellsInTrip,
    bwd.CategoryID,
    
    -- Random subcategory from category (temporary, will update with fast-moving preference)
    (SELECT TOP 1 s.SubcategoryID 
     FROM dbo.DimSubcategories s 
     WHERE s.CategoryID = bwd.CategoryID 
     ORDER BY NEWID()) AS SubcategoryID,
    
    bwd.BellSizeID,
    
    -- TotalItems based on BellSize range
    (SELECT bs.MinItems + (ABS(CHECKSUM(NEWID())) % (bs.MaxItems - bs.MinItems + 1))
     FROM dbo.DimBellSizes bs 
     WHERE bs.BellSizeID = bwd.BellSizeID) AS TotalItems,
    
    -- SellablePercentage: 65%-90%
    CAST((65 + (ABS(CHECKSUM(NEWID())) % 26)) / 100.0 AS DECIMAL(5,2)) AS SellablePercentage,
    
    -- Placeholders for SellableItems, UnsellableItems (calculate next)
    0 AS SellableItems,
    0 AS UnsellableItems,
    
    -- Placeholder for BellCost (calculate next)
    0 AS BellCost,
    0 AS CostPerItem,
    
    CAST(12000.0 / bwd.BellsInTrip AS DECIMAL(10,2)) AS TransportCost
FROM BellsWithDistributions bwd;

-- Calculate SellableItems and UnsellableItems
UPDATE #LoanBells
SET SellableItems = CASE 
    WHEN CAST(TotalItems * SellablePercentage AS INT) < 1 THEN 1 
    ELSE CAST(TotalItems * SellablePercentage AS INT) 
END;

UPDATE #LoanBells
SET UnsellableItems = TotalItems - SellableItems;

-- Update subcategories with fast-moving preference (60%)
UPDATE lb
SET SubcategoryID = (
    SELECT TOP 1 s.SubcategoryID
    FROM dbo.DimSubcategories s
    WHERE s.CategoryID = lb.CategoryID
      AND (
          (s.IsFastMoving = 1 AND (ABS(CHECKSUM(NEWID())) % 100) < 60)
          OR
          (s.IsFastMoving = 0 AND (ABS(CHECKSUM(NEWID())) % 100) >= 60)
      )
    ORDER BY NEWID()
)
FROM #LoanBells lb;

-- Fallback for NULLs
UPDATE lb
SET SubcategoryID = (
    SELECT TOP 1 s.SubcategoryID
    FROM dbo.DimSubcategories s
    WHERE s.CategoryID = lb.CategoryID
    ORDER BY NEWID()
)
FROM #LoanBells lb
WHERE SubcategoryID IS NULL;

-- Calculate BellCost with multi-factor formula
UPDATE lb
SET BellCost = CAST(
    CASE 
        WHEN calc.cost < 350000 THEN 350000
        WHEN calc.cost > 850000 THEN 850000
        ELSE calc.cost
    END AS DECIMAL(12,2))
FROM #LoanBells lb
CROSS APPLY (
    SELECT 
        500000.0 *
        -- Size factor
        CASE lb.BellSizeID 
            WHEN 1 THEN (0.70 + (ABS(CHECKSUM(NEWID())) % 11) / 100.0)
            WHEN 2 THEN (0.90 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 3 THEN (1.20 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
        END *
        -- Category factor
        CASE lb.CategoryID 
            WHEN 1 THEN (0.85 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 2 THEN (0.95 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 3 THEN (1.10 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 4 THEN (0.80 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 5 THEN (1.00 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
        END *
        -- Seasonal factor
        CASE DATEPART(QUARTER, lb.PurchaseDate)
            WHEN 1 THEN (0.90 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
            WHEN 2 THEN (0.95 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
            WHEN 3 THEN (1.05 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
            WHEN 4 THEN (1.10 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
        END AS cost
) AS calc;

-- Calculate CostPerItem
UPDATE #LoanBells
SET CostPerItem = CAST(BellCost / NULLIF(SellableItems, 0) AS DECIMAL(10,2));

PRINT 'Loan bells calculated in temp table';
GO

-- Now INSERT fully-calculated loan bells into FactBells
INSERT INTO dbo.FactBells
(
    PurchaseDateKey,
    CategoryID,
    SubcategoryID,
    BellSizeID,
    BellCost,
    TotalItems,
    SellableItems,
    UnsellableItems,
    SellablePercentage,
    CostPerItem,
    TransportCost,
    LoanID,
    IsProfitFunded,
    TripID
)
SELECT
    CAST(FORMAT(lb.PurchaseDate, 'yyyyMMdd') AS INT),
    lb.CategoryID,
    lb.SubcategoryID,
    lb.BellSizeID,
    lb.BellCost,
    lb.TotalItems,
    lb.SellableItems,
    lb.UnsellableItems,
    lb.SellablePercentage,
    lb.CostPerItem,
    lb.TransportCost,
    lb.LoanID,
    0 AS IsProfitFunded,
    lb.TripID
FROM #LoanBells lb
ORDER BY lb.TripID, lb.LoanID;

DROP TABLE #LoanBellSchedule;
DROP TABLE #LoanBells;

PRINT 'Loan-funded bells inserted with ALL fields calculated';
GO


-- PART 2: PROFIT-FUNDED BELLS

CREATE TABLE #ProfitBellSchedule (
    TripID INT,
    PurchaseDate DATE,
    BellsInTrip INT
);

DECLARE @CurrentMonth INT = 1;
DECLARE @TripCounter INT = 1;

WHILE @CurrentMonth <= 12
BEGIN
    -- Trip 1
    DECLARE @Trip1Date DATE = DATEFROMPARTS(2024, @CurrentMonth, 5 + (ABS(CHECKSUM(NEWID())) % 8));
    WHILE NOT EXISTS (
        SELECT 1 FROM dbo.DimDate 
        WHERE FullDate = @Trip1Date AND IsStoreOpen = 1
    )
    BEGIN 
        SET @Trip1Date = DATEADD(DAY, 1, @Trip1Date); 
    END
    
    INSERT INTO #ProfitBellSchedule (TripID, PurchaseDate, BellsInTrip)
    VALUES (1000 + @TripCounter, @Trip1Date, 1 + (ABS(CHECKSUM(NEWID())) % 3));
    SET @TripCounter = @TripCounter + 1;
    
    -- Trip 2
    DECLARE @Trip2Date DATE = DATEFROMPARTS(2024, @CurrentMonth, 18 + (ABS(CHECKSUM(NEWID())) % 8));
    WHILE NOT EXISTS (
        SELECT 1 FROM dbo.DimDate 
        WHERE FullDate = @Trip2Date AND IsStoreOpen = 1
    )
    BEGIN 
        SET @Trip2Date = DATEADD(DAY, 1, @Trip2Date); 
    END
    
    INSERT INTO #ProfitBellSchedule (TripID, PurchaseDate, BellsInTrip)
    VALUES (1000 + @TripCounter, @Trip2Date, 1 + (ABS(CHECKSUM(NEWID())) % 3));
    SET @TripCounter = @TripCounter + 1;
    SET @CurrentMonth = @CurrentMonth + 1;
END;

PRINT 'Profit schedule created';
GO

-- Create temp table for profit bells with calculations
CREATE TABLE #ProfitBells (
    TripID INT,
    PurchaseDate DATE,
    BellsInTrip INT,
    CategoryID INT,
    SubcategoryID INT,
    BellSizeID INT,
    TotalItems INT,
    SellablePercentage DECIMAL(5,2),
    SellableItems INT,
    UnsellableItems INT,
    BellCost DECIMAL(12,2),
    CostPerItem DECIMAL(10,2),
    TransportCost DECIMAL(10,2)
);

;WITH ProfitBellNumbers AS (
    SELECT 
        pbs.TripID,
        pbs.PurchaseDate,
        pbs.BellsInTrip,
        n.Number AS BellNumberInTrip
    FROM #ProfitBellSchedule pbs
    CROSS JOIN (
        SELECT 1 AS Number UNION ALL SELECT 2 UNION ALL SELECT 3
    ) AS n(Number)
    WHERE n.Number <= pbs.BellsInTrip
),
ProfitBellsWithDistributions AS (
    SELECT 
        pbn.*,
        CASE 
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 25 THEN 1
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 55 THEN 2
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 3
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 90 THEN 4
            ELSE 5
        END AS CategoryID,
        CASE 
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 25 THEN 1
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 2
            ELSE 3
        END AS BellSizeID
    FROM ProfitBellNumbers pbn
)
INSERT INTO #ProfitBells (
    TripID, PurchaseDate, BellsInTrip, 
    CategoryID, SubcategoryID, BellSizeID,
    TotalItems, SellablePercentage, SellableItems, UnsellableItems,
    BellCost, CostPerItem, TransportCost
)
SELECT 
    pwd.TripID,
    pwd.PurchaseDate,
    pwd.BellsInTrip,
    pwd.CategoryID,
    (SELECT TOP 1 s.SubcategoryID 
     FROM dbo.DimSubcategories s 
     WHERE s.CategoryID = pwd.CategoryID 
     ORDER BY NEWID()) AS SubcategoryID,
    pwd.BellSizeID,
    (SELECT bs.MinItems + (ABS(CHECKSUM(NEWID())) % (bs.MaxItems - bs.MinItems + 1))
     FROM dbo.DimBellSizes bs 
     WHERE bs.BellSizeID = pwd.BellSizeID) AS TotalItems,
    CAST((65 + (ABS(CHECKSUM(NEWID())) % 26)) / 100.0 AS DECIMAL(5,2)) AS SellablePercentage,
    0 AS SellableItems,
    0 AS UnsellableItems,
    0 AS BellCost,
    0 AS CostPerItem,
    CAST(12000.0 / pwd.BellsInTrip AS DECIMAL(10,2)) AS TransportCost
FROM ProfitBellsWithDistributions pwd;

-- Calculate SellableItems and UnsellableItems
UPDATE #ProfitBells
SET SellableItems = CASE 
    WHEN CAST(TotalItems * SellablePercentage AS INT) < 1 THEN 1 
    ELSE CAST(TotalItems * SellablePercentage AS INT) 
END;

UPDATE #ProfitBells
SET UnsellableItems = TotalItems - SellableItems;

-- Update subcategories with fast-moving preference
UPDATE pb
SET SubcategoryID = (
    SELECT TOP 1 s.SubcategoryID
    FROM dbo.DimSubcategories s
    WHERE s.CategoryID = pb.CategoryID
      AND (
          (s.IsFastMoving = 1 AND (ABS(CHECKSUM(NEWID())) % 100) < 60)
          OR
          (s.IsFastMoving = 0 AND (ABS(CHECKSUM(NEWID())) % 100) >= 60)
      )
    ORDER BY NEWID()
)
FROM #ProfitBells pb;

-- Fallback
UPDATE pb
SET SubcategoryID = (
    SELECT TOP 1 s.SubcategoryID
    FROM dbo.DimSubcategories s
    WHERE s.CategoryID = pb.CategoryID
    ORDER BY NEWID()
)
FROM #ProfitBells pb
WHERE SubcategoryID IS NULL;

-- Calculate BellCost
UPDATE pb
SET BellCost = CAST(
    CASE 
        WHEN calc.cost < 350000 THEN 350000
        WHEN calc.cost > 850000 THEN 850000
        ELSE calc.cost
    END AS DECIMAL(12,2))
FROM #ProfitBells pb
CROSS APPLY (
    SELECT 
        500000.0 *
        CASE pb.BellSizeID 
            WHEN 1 THEN (0.70 + (ABS(CHECKSUM(NEWID())) % 11) / 100.0)
            WHEN 2 THEN (0.90 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 3 THEN (1.20 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
        END *
        CASE pb.CategoryID 
            WHEN 1 THEN (0.85 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 2 THEN (0.95 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 3 THEN (1.10 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 4 THEN (0.80 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
            WHEN 5 THEN (1.00 + (ABS(CHECKSUM(NEWID())) % 21) / 100.0)
        END *
        CASE DATEPART(QUARTER, pb.PurchaseDate)
            WHEN 1 THEN (0.90 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
            WHEN 2 THEN (0.95 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
            WHEN 3 THEN (1.05 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
            WHEN 4 THEN (1.10 + (ABS(CHECKSUM(NEWID())) % 16) / 100.0)
        END AS cost
) AS calc;

-- Calculate CostPerItem
UPDATE #ProfitBells
SET CostPerItem = CAST(BellCost / NULLIF(SellableItems, 0) AS DECIMAL(10,2));

PRINT 'Profit bells calculated in temp table';
GO

-- INSERT fully-calculated profit bells
INSERT INTO dbo.FactBells
(
    PurchaseDateKey,
    CategoryID,
    SubcategoryID,
    BellSizeID,
    BellCost,
    TotalItems,
    SellableItems,
    UnsellableItems,
    SellablePercentage,
    CostPerItem,
    TransportCost,
    LoanID,
    IsProfitFunded,
    TripID
)
SELECT
    CAST(FORMAT(pb.PurchaseDate, 'yyyyMMdd') AS INT),
    pb.CategoryID,
    pb.SubcategoryID,
    pb.BellSizeID,
    pb.BellCost,
    pb.TotalItems,
    pb.SellableItems,
    pb.UnsellableItems,
    pb.SellablePercentage,
    pb.CostPerItem,
    pb.TransportCost,
    NULL AS LoanID,
    1 AS IsProfitFunded,
    pb.TripID
FROM #ProfitBells pb
ORDER BY pb.TripID;

DROP TABLE #ProfitBellSchedule;
DROP TABLE #ProfitBells;

PRINT 'Profit-funded bells inserted with ALL fields calculated';
GO

-- FACTITEMS GENERATION 

USE AmazingGraceStore;
GO

PRINT 'Starting FactItems generation...';
GO

-- PART 1: Create temp table for item generation

CREATE TABLE #ItemsToGenerate (
    BellID INT,
    CategoryID INT,
    SubcategoryID INT,
    IsFastMoving BIT,
    DateAddedKey INT,
    DateAdded DATE,
    CostPerItem DECIMAL(10,2),
    ItemNumber INT,
    PurchaseQuarter INT
);

;WITH BellItemCounts AS (
    SELECT 
        fb.BellID,
        fb.CategoryID,
        fb.SubcategoryID,
        s.IsFastMoving,
        fb.PurchaseDateKey AS DateAddedKey,
        CAST(CAST(fb.PurchaseDateKey AS VARCHAR(8)) AS DATE) AS DateAdded,
        fb.CostPerItem,
        fb.SellableItems,
        DATEPART(QUARTER, CAST(CAST(fb.PurchaseDateKey AS VARCHAR(8)) AS DATE)) AS PurchaseQuarter
    FROM dbo.FactBells fb
    JOIN dbo.DimSubcategories s ON fb.SubcategoryID = s.SubcategoryID
),
Numbers AS (
    SELECT TOP 500 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Num
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO #ItemsToGenerate (
    BellID, CategoryID, SubcategoryID, IsFastMoving, 
    DateAddedKey, DateAdded, CostPerItem, ItemNumber, PurchaseQuarter
)
SELECT 
    bic.BellID,
    bic.CategoryID,
    bic.SubcategoryID,
    bic.IsFastMoving,
    bic.DateAddedKey,
    bic.DateAdded,
    bic.CostPerItem,
    n.Num AS ItemNumber,
    bic.PurchaseQuarter
FROM BellItemCounts bic
CROSS JOIN Numbers n
WHERE n.Num <= bic.SellableItems;

PRINT 'Item generation template created';
SELECT 'Total Items to Generate' AS Status, COUNT(*) AS Count FROM #ItemsToGenerate;
GO

-- PART 2: Generate items with all calculations

CREATE TABLE #GeneratedItems (
    BellID INT,
    CategoryID INT,
    SubcategoryID INT,
    GradeID INT,
    CostPerItem DECIMAL(10,2),
    BasePrice DECIMAL(10,2),
    IsTopTier BIT,
    ActualMarkupPercent DECIMAL(5,2),
    SellingPrice DECIMAL(10,2),
    DateAddedKey INT,
    DateAdded DATE,
    IsFastMoving BIT,
    PurchaseQuarter INT,
    DaysToSale INT,
    DateSoldKey INT,
    DateSold DATE,
    IsSold BIT,
    IsInDiscount BIT,
    DiscountPercent DECIMAL(5,2),
    DiscountedPrice DECIMAL(10,2),
    FinalSalePrice DECIMAL(10,2)
);

INSERT INTO #GeneratedItems (
    BellID, CategoryID, SubcategoryID, GradeID, CostPerItem,
    BasePrice, IsTopTier, ActualMarkupPercent, SellingPrice,
    DateAddedKey, DateAdded, IsFastMoving, PurchaseQuarter,
    DaysToSale, DateSoldKey, DateSold, IsSold,
    IsInDiscount, DiscountPercent, DiscountedPrice, FinalSalePrice
)
SELECT 
    itg.BellID,
    itg.CategoryID,
    itg.SubcategoryID,
    CASE WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 1 ELSE 2 END AS GradeID,
    itg.CostPerItem,
    0 AS BasePrice,
    0 AS IsTopTier,
    0.00 AS ActualMarkupPercent,
    0.00 AS SellingPrice,
    itg.DateAddedKey,
    itg.DateAdded,
    itg.IsFastMoving,
    itg.PurchaseQuarter,
    0 AS DaysToSale,
    NULL AS DateSoldKey,
    NULL AS DateSold,
    0 AS IsSold,
    0 AS IsInDiscount,
    NULL AS DiscountPercent,
    NULL AS DiscountedPrice,
    NULL AS FinalSalePrice
FROM #ItemsToGenerate itg;

PRINT 'Items inserted with grade distribution';
GO

-- Update IsTopTier (15% of Grade 1 items only)
UPDATE #GeneratedItems
SET IsTopTier = CASE 
    WHEN GradeID = 1 AND (ABS(CHECKSUM(NEWID())) % 100) < 15 THEN 1 
    ELSE 0 
END;

-- Update ActualMarkupPercent
UPDATE #GeneratedItems
SET ActualMarkupPercent = CASE 
    WHEN IsTopTier = 1 THEN 50.00
    ELSE CAST(20.0 + (ABS(CHECKSUM(NEWID())) % 11) AS DECIMAL(5,2))
END;

-- Calculate SellingPrice
UPDATE #GeneratedItems
SET 
    BasePrice = CAST(CostPerItem * (1 + ActualMarkupPercent / 100.0) AS DECIMAL(10,2)),
    SellingPrice = CAST(CostPerItem * (1 + ActualMarkupPercent / 100.0) AS DECIMAL(10,2));

PRINT 'Pricing calculated';
GO

-- PART 3: SELL-THROUGH SIMULATION (Your improved logic)

;WITH SellProbabilityCalc AS (
    SELECT 
        gi.*,
        -- Base probability factors
        CASE WHEN gi.IsFastMoving = 1 THEN 0.95 ELSE 0.75 END AS FastMovingFactor,
        
        -- Seasonal factor (based on purchase quarter)
        CASE gi.PurchaseQuarter
            WHEN 1 THEN 0.85  -- Q1 (Jan-Mar): Post-holiday slow
            WHEN 2 THEN 1.05  -- Q2 (Apr-Jun): Spring moderate
            WHEN 3 THEN 1.20  -- Q3 (Jul-Sep): Back-to-school/university peak
            WHEN 4 THEN 1.35  -- Q4 (Oct-Dec): Holiday peak
        END AS SeasonalFactor,
        
        -- Price factor
        CASE 
            WHEN gi.SellingPrice < 3000 THEN 1.55
            WHEN gi.SellingPrice BETWEEN 3000 AND 6000 THEN 1.30
            ELSE 1.1
        END AS PriceFactor,
        
        -- Random factor for variation
        ((ABS(CHECKSUM(NEWID())) % 50) + 50) / 100.0 AS RandomFactor
    FROM #GeneratedItems gi
)
UPDATE gi
SET IsSold = CASE 
    WHEN (spc.FastMovingFactor * spc.SeasonalFactor * spc.PriceFactor * spc.RandomFactor) > 0.60 
    THEN 1 
    ELSE 0 
END
FROM #GeneratedItems gi
JOIN SellProbabilityCalc spc ON 
    gi.BellID = spc.BellID AND 
    gi.CategoryID = spc.CategoryID AND 
    gi.SubcategoryID = spc.SubcategoryID AND
    gi.CostPerItem = spc.CostPerItem AND
    gi.DateAddedKey = spc.DateAddedKey;

PRINT 'Sell-through simulation complete (improved logic)';
SELECT 'Items Sold' AS Metric, COUNT(*) AS Count FROM #GeneratedItems WHERE IsSold = 1
UNION ALL
SELECT 'Items Unsold', COUNT(*) FROM #GeneratedItems WHERE IsSold = 0;
GO

-- PART 4: CALCULATE DAYS TO SALE FOR SOLD ITEMS

-- For fast-moving items: 5-45 days
UPDATE #GeneratedItems
SET DaysToSale = 5 + (ABS(CHECKSUM(NEWID())) % 41)
WHERE IsSold = 1 AND IsFastMoving = 1;

-- For regular items: 10-90 days
UPDATE #GeneratedItems
SET DaysToSale = 10 + (ABS(CHECKSUM(NEWID())) % 81)
WHERE IsSold = 1 AND IsFastMoving = 0;

-- Calculate DateSold using DimDate (store open days only)
UPDATE gi
SET 
    DateSold = d.FullDate,
    DateSoldKey = d.DateKey
FROM #GeneratedItems gi
CROSS APPLY (
    SELECT TOP 1 dd.FullDate, dd.DateKey
    FROM dbo.DimDate dd
    WHERE dd.FullDate >= DATEADD(DAY, gi.DaysToSale, gi.DateAdded)
      AND dd.IsStoreOpen = 1
      AND dd.FullDate <= '2024-12-31'
    ORDER BY dd.FullDate
) d
WHERE gi.IsSold = 1;

-- Items that would sell beyond year-end: mark as unsold
UPDATE #GeneratedItems
SET 
    IsSold = 0,
    DaysToSale = 0,
    DateSold = NULL,
    DateSoldKey = NULL
WHERE IsSold = 1 AND DateSoldKey IS NULL;

PRINT 'Sale dates assigned using DimDate';
GO

-- PART 5: DISCOUNT LOGIC FOR UNSOLD ITEMS

-- Calculate age for unsold items AND check if any sales period exists for that age
;WITH ItemAgeAndSalesPeriod AS (
    SELECT 
        gi.BellID,
        gi.CategoryID,
        gi.SubcategoryID,
        gi.CostPerItem,
        gi.DateAddedKey,
        gi.DateAdded,
        DATEDIFF(DAY, gi.DateAdded, '2024-12-31') AS DaysInInventory,
        -- Check if item qualifies for discount (90+ days AND in sales period)
        CASE 
            WHEN DATEDIFF(DAY, gi.DateAdded, '2024-12-31') >= 90 THEN
                -- Check if ANY date in Nov sales period (Nov 4-24) exists after item was 90 days old
                CASE WHEN EXISTS (
                    SELECT 1 FROM dbo.DimDate d
                    WHERE d.IsSalesPeriod = 1
                      AND d.FullDate >= DATEADD(DAY, 90, gi.DateAdded)
                      AND d.FullDate <= '2024-12-31'
                ) THEN 1 ELSE 0 END
            ELSE 0
        END AS QualifiesForDiscount
    FROM #GeneratedItems gi
    WHERE gi.IsSold = 0
)
UPDATE gi
SET 
    IsInDiscount = iasp.QualifiesForDiscount,
    DiscountPercent = CASE 
        WHEN iasp.QualifiesForDiscount = 1 THEN
            CASE 
                WHEN iasp.DaysInInventory >= 180 THEN 50.00
                WHEN iasp.DaysInInventory >= 120 THEN 40.00
                WHEN iasp.DaysInInventory >= 90 THEN 25.00
                ELSE NULL
            END
        ELSE NULL
    END
FROM #GeneratedItems gi
JOIN ItemAgeAndSalesPeriod iasp ON 
    gi.BellID = iasp.BellID AND 
    gi.CategoryID = iasp.CategoryID AND 
    gi.SubcategoryID = iasp.SubcategoryID AND
    gi.CostPerItem = iasp.CostPerItem AND
    gi.DateAddedKey = iasp.DateAddedKey
WHERE gi.IsSold = 0;

-- Calculate discounted prices
UPDATE #GeneratedItems
SET DiscountedPrice = CAST(
    SellingPrice * (1 - DiscountPercent / 100.0) AS DECIMAL(10,2)
)
WHERE IsInDiscount = 1 AND DiscountPercent IS NOT NULL;

PRINT 'Discount logic applied (only items 90+ days old in sales periods)';
SELECT 
    'Items Qualifying for Discount' AS Metric, 
    COUNT(*) AS Count,
    'Items 90+ days old during sales period' AS Note
FROM #GeneratedItems 
WHERE IsInDiscount = 1;
GO

-- PART 6: DETERMINE FINAL SALE PRICE

UPDATE gi
SET FinalSalePrice = CASE 
    WHEN gi.IsInDiscount = 1 AND gi.DiscountedPrice IS NOT NULL 
    THEN gi.DiscountedPrice
    ELSE gi.SellingPrice
END
FROM #GeneratedItems gi
WHERE gi.IsSold = 1;

PRINT 'Final sale prices calculated';
GO

-- PART 7: INSERT INTO FactItems

INSERT INTO dbo.FactItems
(
    BellID,
    CategoryID,
    SubcategoryID,
    GradeID,
    CostPerItem,
    BasePrice,
    IsTopTier,
    ActualMarkupPercent,
    SellingPrice,
    DateAddedKey,
    DateSoldKey,
    DaysInInventory,
    IsSold,
    IsInDiscount,
    DiscountPercent,
    DiscountedPrice,
    FinalSalePrice,
    SaleTransactionID
)
SELECT 
    gi.BellID,
    gi.CategoryID,
    gi.SubcategoryID,
    gi.GradeID,
    gi.CostPerItem,
    gi.BasePrice,
    gi.IsTopTier,
    gi.ActualMarkupPercent,
    gi.SellingPrice,
    gi.DateAddedKey,
    gi.DateSoldKey,
    gi.DaysToSale AS DaysInInventory,
    gi.IsSold,
    gi.IsInDiscount,
    gi.DiscountPercent,
    gi.DiscountedPrice,
    gi.FinalSalePrice,
    NULL AS SaleTransactionID  -- Will be populated in FactSales generation
FROM #GeneratedItems gi
ORDER BY gi.BellID, gi.CategoryID;

DROP TABLE #ItemsToGenerate;
DROP TABLE #GeneratedItems;

PRINT 'FactItems populated successfully!';
GO



PRINT 'Starting FactSales generation...';
GO

--PART 1: Identify sold items grouped by sale date

CREATE TABLE #SoldItemsByDate (
    ItemID BIGINT,
    DateSoldKey INT,
    DateSold DATE,
    SellingPrice DECIMAL(10,2),
    DiscountedPrice DECIMAL(10,2),
    FinalSalePrice DECIMAL(10,2),
    IsFastMoving BIT,
    IsInDiscount BIT,
    ItemRank INT
);

INSERT INTO #SoldItemsByDate
SELECT 
    fi.ItemID,
    fi.DateSoldKey,
    CAST(CAST(fi.DateSoldKey AS VARCHAR(8)) AS DATE),
    fi.SellingPrice,
    fi.DiscountedPrice,
    fi.FinalSalePrice,
    s.IsFastMoving,
    fi.IsInDiscount,
    ROW_NUMBER() OVER (
        PARTITION BY fi.DateSoldKey
        ORDER BY NEWID()
    )
FROM dbo.FactItems fi
JOIN dbo.DimSubcategories s 
    ON fi.SubcategoryID = s.SubcategoryID
WHERE fi.IsSold = 1
  AND fi.DateSoldKey IS NOT NULL
  AND fi.FinalSalePrice IS NOT NULL;

GO


--PART 2: Daily transaction targets

CREATE TABLE #DailyTransactionTargets (
    DateSoldKey INT,
    DateSold DATE,
    DayOfWeek NVARCHAR(20),
    IsPeakPeriod BIT,
    IsSalesPeriod BIT,
    TotalItemsSold INT
);

INSERT INTO #DailyTransactionTargets
SELECT 
    sibd.DateSoldKey,
    sibd.DateSold,
    d.DayName,
    d.IsPeakPeriod,
    d.IsSalesPeriod,
    COUNT(*)
FROM #SoldItemsByDate sibd
JOIN dbo.DimDate d 
    ON sibd.DateSoldKey = d.DateKey
GROUP BY 
    sibd.DateSoldKey,
    sibd.DateSold,
    d.DayName,
    d.IsPeakPeriod,
    d.IsSalesPeriod;

GO


--PART 3: Create transaction groups

CREATE TABLE #TransactionGroups (
    TransactionGroupID INT IDENTITY(1,1),
    DateSoldKey INT,
    DateSold DATE,
    TransactionSize INT,
    StartItemRank INT,
    EndItemRank INT
);

DECLARE 
    @DateKey INT,
    @DateSold DATE,
    @TotalItems INT,
    @Rank INT,
    @Size INT,
    @Rand INT;

DECLARE cur CURSOR FOR
SELECT DateSoldKey, DateSold, TotalItemsSold
FROM #DailyTransactionTargets
ORDER BY DateSoldKey;

OPEN cur;
FETCH NEXT FROM cur INTO @DateKey, @DateSold, @TotalItems;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Rank = 1;

    WHILE @Rank <= @TotalItems
    BEGIN
        SET @Rand = ABS(CHECKSUM(NEWID())) % 100;

        SET @Size =
            CASE
                WHEN @Rand < 45 THEN 1
                WHEN @Rand < 70 THEN 2 + ABS(CHECKSUM(NEWID())) % 3
                WHEN @Rand < 85 THEN 5 + ABS(CHECKSUM(NEWID())) % 4
                WHEN @Rand < 95 THEN 9 + ABS(CHECKSUM(NEWID())) % 2
                ELSE 11 + ABS(CHECKSUM(NEWID())) % 40
            END;

        IF @Rank + @Size - 1 > @TotalItems
            SET @Size = @TotalItems - @Rank + 1;

        INSERT INTO #TransactionGroups
        VALUES (
            @DateKey,
            @DateSold,
            @Size,
            @Rank,
            @Rank + @Size - 1
        );

        SET @Rank += @Size;
    END;

    FETCH NEXT FROM cur INTO @DateKey, @DateSold, @TotalItems;
END;

CLOSE cur;
DEALLOCATE cur;

GO


--PART 4: Build Sales Transactions

CREATE TABLE #SalesTransactions (
    TempSaleID INT IDENTITY(1,1),
    TransactionGroupID INT,
    SaleDateKey INT,
    SaleDateTime DATETIME,
    TotalItems INT,
    SubtotalAmount DECIMAL(12,2),
    DiscountAmount DECIMAL(12,2),
    TotalAmount DECIMAL(12,2),
    PaymentMethod NVARCHAR(20),
    IsRecurringCustomer BIT
);

INSERT INTO #SalesTransactions
SELECT
    tg.TransactionGroupID,
    tg.DateSoldKey,
    CAST(tg.DateSold AS DATETIME)
      + CAST(
            CAST(9 + ABS(CHECKSUM(NEWID())) % 12 AS VARCHAR)
            + ':' + CAST(ABS(CHECKSUM(NEWID())) % 60 AS VARCHAR)
            + ':' + CAST(ABS(CHECKSUM(NEWID())) % 60 AS VARCHAR)
        AS DATETIME),
    tg.TransactionSize,
    SUM(s.FinalSalePrice),
    SUM(s.SellingPrice - s.FinalSalePrice),
    SUM(s.FinalSalePrice),
    CASE
        WHEN ABS(CHECKSUM(NEWID())) % 100 < 30 THEN 'Cash'
        WHEN ABS(CHECKSUM(NEWID())) % 100 < 75 THEN 'Transfer'
        ELSE 'POS'
    END,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 35 THEN 1 ELSE 0 END
FROM #TransactionGroups tg
JOIN #SoldItemsByDate s
    ON s.DateSoldKey = tg.DateSoldKey
   AND s.ItemRank BETWEEN tg.StartItemRank AND tg.EndItemRank
GROUP BY
    tg.TransactionGroupID,
    tg.DateSoldKey,
    tg.DateSold,
    tg.TransactionSize;

GO


--PART 5: INSERT INTO FactSales (CORRECTED)
IF COL_LENGTH('tempdb..#SalesTransactions', 'ActualSaleTransactionID') IS NULL
BEGIN
    ALTER TABLE #SalesTransactions
    ADD ActualSaleTransactionID BIGINT NULL;
END;
GO

DECLARE @InsertedSales TABLE (
    SaleTransactionID BIGINT,
    RowNum INT
);

MERGE dbo.FactSales AS tgt
USING (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY TempSaleID) AS RowNum
    FROM #SalesTransactions
) AS src
ON 1 = 0
WHEN NOT MATCHED THEN
    INSERT (
        SaleDateKey,
        SaleDateTime,
        TotalItems,
        SubtotalAmount,
        DiscountAmount,
        TotalAmount,
        PaymentMethod,
        IsRecurringCustomer
    )
    VALUES (
        src.SaleDateKey,
        src.SaleDateTime,
        src.TotalItems,
        src.SubtotalAmount,
        src.DiscountAmount,
        src.TotalAmount,
        src.PaymentMethod,
        src.IsRecurringCustomer
    )
OUTPUT
    INSERTED.SaleTransactionID,
    src.RowNum
INTO @InsertedSales;

;WITH NumberedTemp AS (
    SELECT TempSaleID,
           ROW_NUMBER() OVER (ORDER BY TempSaleID) AS RowNum
    FROM #SalesTransactions
)
UPDATE st
SET ActualSaleTransactionID = ins.SaleTransactionID
FROM #SalesTransactions st
JOIN NumberedTemp nt ON st.TempSaleID = nt.TempSaleID
JOIN @InsertedSales ins ON nt.RowNum = ins.RowNum;

GO


--PART 6: UPDATE FactItems
UPDATE fi
SET SaleTransactionID = st.ActualSaleTransactionID
FROM dbo.FactItems fi
JOIN #SoldItemsByDate s ON fi.ItemID = s.ItemID
JOIN #TransactionGroups tg
    ON s.DateSoldKey = tg.DateSoldKey
   AND s.ItemRank BETWEEN tg.StartItemRank AND tg.EndItemRank
JOIN #SalesTransactions st
    ON tg.TransactionGroupID = st.TransactionGroupID;

GO


--VERIFICATION
SELECT COUNT(*) AS Mismatches
FROM dbo.FactSales fs
JOIN dbo.FactItems fi
    ON fs.SaleTransactionID = fi.SaleTransactionID
GROUP BY fs.SaleTransactionID, fs.TotalAmount
HAVING ABS(fs.TotalAmount - SUM(fi.FinalSalePrice)) > 0.01;

PRINT '✓ FactSales generation completed successfully';
GO

-- FACTEXPENSES GENERATION SCRIPT 

PRINT 'Starting FactExpenses generation...';
GO

-- PART 1: RECURRING EXPENSES

CREATE TABLE #RecurringExpenses (
    ExpenseCategory NVARCHAR(50),
    ExpenseDescription NVARCHAR(200),
    Amount DECIMAL(12,2),
    DueDay INT,
    IsRecurring BIT,
    PaymentMethod NVARCHAR(20)
);

INSERT INTO #RecurringExpenses (
    ExpenseCategory, ExpenseDescription, Amount, 
    DueDay, IsRecurring, PaymentMethod
)
VALUES
    ('Rent', 'Monthly shop rent', 150000.00, 1, 1, 'Transfer'),
    ('Staff', 'Staff salaries (2 employees)', 0, 25, 1, 'Cash');
GO

-- Generate monthly recurring expenses
INSERT INTO dbo.FactExpenses (
    ExpenseDateKey,
    ExpenseCategory,
    ExpenseDescription,
    Amount,
    IsRecurring,
    PaymentMethod
)
SELECT 
    d.DateKey,
    re.ExpenseCategory,
    re.ExpenseDescription + ' - ' + d.MonthName AS ExpenseDescription,
    CASE 
        WHEN re.ExpenseCategory = 'Rent' THEN re.Amount
        WHEN re.ExpenseCategory = 'Staff' THEN 
            CAST(200000 + (ABS(CHECKSUM(NEWID())) % 201000) AS DECIMAL(12,2))
    END AS Amount,
    re.IsRecurring,
    re.PaymentMethod
FROM #RecurringExpenses re
CROSS JOIN dbo.DimDate d
WHERE d.Year = 2024
  AND DAY(d.FullDate) = re.DueDay
  AND d.IsStoreOpen = 1;

DROP TABLE #RecurringExpenses;

PRINT 'Recurring expenses generated (Rent + Staff)';
SELECT 
    'Recurring Expenses' AS Status,
    COUNT(*) AS Count,
    '24 expected (12 rent + 12 staff)' AS Expected
FROM dbo.FactExpenses
WHERE IsRecurring = 1;
GO

-- PART 2: UTILITIES (Monthly Variable)

;WITH MonthlyUtilityDates AS (
    SELECT 
        d.DateKey,
        d.Month,
        d.MonthName,
        ROW_NUMBER() OVER (PARTITION BY d.Month ORDER BY NEWID()) AS RowNum
    FROM dbo.DimDate d
    WHERE d.Year = 2024
      AND DAY(d.FullDate) BETWEEN 5 AND 10
      AND d.IsStoreOpen = 1
)
INSERT INTO dbo.FactExpenses (
    ExpenseDateKey,
    ExpenseCategory,
    ExpenseDescription,
    Amount,
    IsRecurring,
    PaymentMethod
)
SELECT 
    mud.DateKey,
    'Utilities' AS ExpenseCategory,
    'Electricity, water, internet - ' + mud.MonthName AS ExpenseDescription,
    CAST(
        CASE 
            WHEN mud.Month IN (3,4,5,6,7,8,9) THEN 50000 + (ABS(CHECKSUM(NEWID())) % 31000)
            ELSE 30000 + (ABS(CHECKSUM(NEWID())) % 21000)
        END 
        AS DECIMAL(12,2)
    ) AS Amount,
    0 AS IsRecurring,
    CASE WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 'Transfer' ELSE 'Cash' END AS PaymentMethod
FROM MonthlyUtilityDates mud
WHERE mud.RowNum = 1;

PRINT 'Utilities expenses generated';
SELECT 
    'Utilities Expenses' AS Status,
    COUNT(*) AS Count,
    '12 expected (monthly)' AS Expected
FROM dbo.FactExpenses
WHERE ExpenseCategory = 'Utilities';
GO

-- PART 3: TRANSPORT (Ad-hoc trips)

DECLARE @TransportCount INT = 30 + (ABS(CHECKSUM(NEWID())) % 11);
DECLARE @TransportCounter INT = 0;

WHILE @TransportCounter < @TransportCount
BEGIN
    DECLARE @TransportDate DATE = (
        SELECT TOP 1 FullDate
        FROM dbo.DimDate
        WHERE Year = 2024
          AND IsStoreOpen = 1
        ORDER BY NEWID()
    );
    
    INSERT INTO dbo.FactExpenses (
        ExpenseDateKey,
        ExpenseCategory,
        ExpenseDescription,
        Amount,
        IsRecurring,
        PaymentMethod
    )
    VALUES (
        CAST(FORMAT(@TransportDate, 'yyyyMMdd') AS INT),
        'Transport',
        'Transportation for supplies/errands',
        12000.00,
        0,
        'Cash'
    );
    
    SET @TransportCounter = @TransportCounter + 1;
END;

PRINT 'Transport expenses generated';
SELECT 
    'Transport Expenses' AS Status,
    COUNT(*) AS Count,
    '30-40 expected' AS Expected
FROM dbo.FactExpenses
WHERE ExpenseCategory = 'Transport';
GO

-- PART 4: OTHER EXPENSES

DECLARE @OtherCount INT = 40 + (ABS(CHECKSUM(NEWID())) % 21);
DECLARE @OtherCounter INT = 0;

WHILE @OtherCounter < @OtherCount
BEGIN
    DECLARE @OtherDate DATE = (
        SELECT TOP 1 FullDate
        FROM dbo.DimDate
        WHERE Year = 2024
          AND IsStoreOpen = 1
        ORDER BY NEWID()
    );
    
    DECLARE @OtherRand INT = ABS(CHECKSUM(NEWID())) % 100;
    DECLARE @OtherDesc NVARCHAR(200);
    DECLARE @OtherAmount DECIMAL(12,2);
    
    IF @OtherRand < 30
    BEGIN
        SET @OtherDesc = 'Shop repairs and maintenance';
        SET @OtherAmount = 20000 + (ABS(CHECKSUM(NEWID())) % 81000);
    END
    ELSE IF @OtherRand < 60
    BEGIN
        SET @OtherDesc = 'Shop supplies (hangers, bags, tags)';
        SET @OtherAmount = 10000 + (ABS(CHECKSUM(NEWID())) % 41000);
    END
    ELSE IF @OtherRand < 85
    BEGIN
        SET @OtherDesc = 'Marketing and promotions';
        SET @OtherAmount = 15000 + (ABS(CHECKSUM(NEWID())) % 86000);
    END
    ELSE
    BEGIN
        SET @OtherDesc = 'Miscellaneous business expenses';
        SET @OtherAmount = 10000 + (ABS(CHECKSUM(NEWID())) % 41000);
    END;
    
    INSERT INTO dbo.FactExpenses (
        ExpenseDateKey,
        ExpenseCategory,
        ExpenseDescription,
        Amount,
        IsRecurring,
        PaymentMethod
    )
    VALUES (
        CAST(FORMAT(@OtherDate, 'yyyyMMdd') AS INT),
        'Other',
        @OtherDesc,
        @OtherAmount,
        0,
        CASE WHEN (ABS(CHECKSUM(NEWID())) % 100) < 40 THEN 'Cash' ELSE 'Transfer' END
    );
    
    SET @OtherCounter = @OtherCounter + 1;
END;

PRINT 'Other expenses generated';
SELECT 
    'Other Expenses' AS Status,
    COUNT(*) AS Count,
    '40-60 expected' AS Expected
FROM dbo.FactExpenses
WHERE ExpenseCategory = 'Other';
GO

-- FACTCASHMOVEMENTS GENERATION SCRIPT 


PRINT 'Starting FactCashMovements generation with daily deficit prevention...';
GO

-- STEP 1: SET OPENING BALANCES 

DECLARE @OpeningDate INT = 20240104;

-- Profits Account Opening Balance: ₦250,000
INSERT INTO dbo.FactCashMovements (
    MovementDateKey, AccountType, MovementType, Amount,
    SourceAccount, DestinationAccount, Description, RunningBalance
)
VALUES (
    @OpeningDate, 'Profits', 'Deposit', 250000.00,
    NULL, NULL, 'Opening balance', 250000.00
);

-- Operations Account Opening Balance: ₦100,000
INSERT INTO dbo.FactCashMovements (
    MovementDateKey, AccountType, MovementType, Amount,
    SourceAccount, DestinationAccount, Description, RunningBalance
)
VALUES (
    @OpeningDate, 'Operations', 'Deposit', 100000.00,
    NULL, NULL, 'Opening balance', 100000.00
);

-- Debts Account Opening Balance: ₦0
-- No INSERT needed - account starts at zero with first loan disbursement

PRINT 'Opening balances set: Profits ₦250K, Operations ₦100K, Debts ₦0 (implicit)';
GO

-- STEP 2: CREATE DAILY MOVEMENTS TEMP TABLE

CREATE TABLE #DailyMovements (
    ProcessDate DATE,
    DateKey INT,
    AccountType NVARCHAR(20),
    MovementType NVARCHAR(20),
    Amount DECIMAL(12,2),
    SourceAccount NVARCHAR(20),
    DestinationAccount NVARCHAR(20),
    Description NVARCHAR(200),
    ProcessOrder INT
);

PRINT 'Temp table created';
GO

-- STEP 3: GENERATE ALL MOVEMENTS

-- 3.1: LOAN DISBURSEMENTS (Morning, Order 1)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(LoanDateKey AS VARCHAR(8)) AS DATE),
    LoanDateKey,
    'Debts',
    'Deposit',
    PrincipalAmount,
    NULL, NULL,
    'Loan disbursement (Loan ID: ' + CAST(LoanID AS VARCHAR) + ')',
    1
FROM dbo.FactLoans;

-- 3.2: LOAN-FUNDED BELL PURCHASES (Morning, Order 2)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(PurchaseDateKey AS VARCHAR(8)) AS DATE),
    PurchaseDateKey,
    'Debts',
    'Withdrawal',
    SUM(BellCost),
    NULL, NULL,
    'Loan-funded bell purchases',
    2
FROM dbo.FactBells
WHERE IsProfitFunded = 0
GROUP BY PurchaseDateKey;

-- 3.3: PROFIT-FUNDED BELL PURCHASES (Morning, Order 3)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(PurchaseDateKey AS VARCHAR(8)) AS DATE),
    PurchaseDateKey,
    'Operations',
    'Withdrawal',
    SUM(BellCost),
    NULL, NULL,
    'Profit-funded bell purchases',
    3
FROM dbo.FactBells
WHERE IsProfitFunded = 1
GROUP BY PurchaseDateKey;

-- 3.4: TRANSPORT COSTS (Morning, Order 4)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(PurchaseDateKey AS VARCHAR(8)) AS DATE),
    PurchaseDateKey,
    'Operations',
    'Withdrawal',
    SUM(TransportCost),
    NULL, NULL,
    'Transport costs',
    4
FROM dbo.FactBells
GROUP BY PurchaseDateKey;

-- 3.5: EXPENSES (Throughout day, Order 5)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(ExpenseDateKey AS VARCHAR(8)) AS DATE),
    ExpenseDateKey,
    'Operations',
    'Withdrawal',
    SUM(Amount),
    NULL, NULL,
    'Daily expenses',
    5
FROM dbo.FactExpenses
GROUP BY ExpenseDateKey;

-- 3.6: DAILY SALES REVENUE (End of day, Order 6)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(SaleDateKey AS VARCHAR(8)) AS DATE),
    SaleDateKey,
    'Profits',
    'Deposit',
    SUM(TotalAmount),
    NULL, NULL,
    'Daily sales revenue',
    6
FROM dbo.FactSales
GROUP BY SaleDateKey;

-- 3.7: 70% SALES → OPERATIONS (End of day, Order 7)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(SaleDateKey AS VARCHAR(8)) AS DATE),
    SaleDateKey,
    'Profits',
    'Transfer',
    SUM(TotalAmount) * 0.70,
    'Profits', 'Operations',
    '70% of daily sales to Operations',
    7
FROM dbo.FactSales
GROUP BY SaleDateKey;

INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(SaleDateKey AS VARCHAR(8)) AS DATE),
    SaleDateKey,
    'Operations',
    'Transfer',
    SUM(TotalAmount) * 0.70,
    'Profits', 'Operations',
    'Receive 70% from Profits',
    7
FROM dbo.FactSales
GROUP BY SaleDateKey;

-- 3.8: 65% OF OPERATIONS INFLOW → DEBTS (End of day, Order 8)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(SaleDateKey AS VARCHAR(8)) AS DATE),
    SaleDateKey,
    'Operations',
    'Transfer',
    SUM(TotalAmount) * 0.70 * 0.65,
    'Operations', 'Debts',
    '65% of Operations inflow to Debts',
    8
FROM dbo.FactSales
GROUP BY SaleDateKey;

INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(SaleDateKey AS VARCHAR(8)) AS DATE),
    SaleDateKey,
    'Debts',
    'Transfer',
    SUM(TotalAmount) * 0.70 * 0.65,
    'Operations', 'Debts',
    'Receive 65% from Operations',
    8
FROM dbo.FactSales
GROUP BY SaleDateKey;

-- 3.9: LOAN REPAYMENTS (End of day, Order 9)
INSERT INTO #DailyMovements
SELECT 
    CAST(CAST(RepaymentDateKey AS VARCHAR(8)) AS DATE),
    RepaymentDateKey,
    'Debts',
    'Withdrawal',
    SUM(ActualAmount),
    NULL, NULL,
    'Loan repayment',
    9
FROM dbo.FactLoanRepayments
GROUP BY RepaymentDateKey;

PRINT 'All movements queued';
GO

-- STEP 4: PROCESS MOVEMENTS DAY BY DAY WITH DEFICIT CHECKS

-- Track balances in memory
CREATE TABLE #CurrentBalances (
    AccountType NVARCHAR(20) PRIMARY KEY,
    Balance DECIMAL(12,2)
);

INSERT INTO #CurrentBalances VALUES ('Profits', 250000.00);
INSERT INTO #CurrentBalances VALUES ('Operations', 100000.00);
INSERT INTO #CurrentBalances VALUES ('Debts', 0.00);

-- Get all unique dates
DECLARE @ProcessDate DATE;
DECLARE @DateKey INT;

DECLARE date_cursor CURSOR FOR
SELECT DISTINCT ProcessDate, DateKey
FROM #DailyMovements
WHERE ProcessDate >= '2024-01-04'
ORDER BY ProcessDate;

OPEN date_cursor;
FETCH NEXT FROM date_cursor INTO @ProcessDate, @DateKey;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Processing date: ' + CAST(@ProcessDate AS VARCHAR(20));
    
    -- Process movements in order for this date
    DECLARE @AccountType NVARCHAR(20);
    DECLARE @MovementType NVARCHAR(20);
    DECLARE @Amount DECIMAL(12,2);
    DECLARE @SourceAccount NVARCHAR(20);
    DECLARE @DestinationAccount NVARCHAR(20);
    DECLARE @Description NVARCHAR(200);
    DECLARE @CurrentBalance DECIMAL(12,2);
    
    DECLARE movement_cursor CURSOR FOR
    SELECT AccountType, MovementType, Amount, SourceAccount, DestinationAccount, Description
    FROM #DailyMovements
    WHERE DateKey = @DateKey
    ORDER BY ProcessOrder, AccountType;
    
    OPEN movement_cursor;
    FETCH NEXT FROM movement_cursor INTO 
        @AccountType, @MovementType, @Amount, @SourceAccount, @DestinationAccount, @Description;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get current balance
        SELECT @CurrentBalance = Balance FROM #CurrentBalances WHERE AccountType = @AccountType;
        
        -- Calculate new balance
        IF @MovementType = 'Deposit'
            SET @CurrentBalance = @CurrentBalance + @Amount;
        ELSE IF @MovementType = 'Withdrawal'
            SET @CurrentBalance = @CurrentBalance - @Amount;
        ELSE IF @MovementType = 'Transfer'
        BEGIN
            IF @AccountType = @SourceAccount
                SET @CurrentBalance = @CurrentBalance - @Amount;
            ELSE IF @AccountType = @DestinationAccount
                SET @CurrentBalance = @CurrentBalance + @Amount;
        END
        
        -- Insert movement
        INSERT INTO dbo.FactCashMovements (
            MovementDateKey, AccountType, MovementType, Amount,
            SourceAccount, DestinationAccount, Description, RunningBalance
        )
        VALUES (
            @DateKey, @AccountType, @MovementType, @Amount,
            @SourceAccount, @DestinationAccount, @Description, @CurrentBalance
        );
        
        -- Update balance tracker
        UPDATE #CurrentBalances SET Balance = @CurrentBalance WHERE AccountType = @AccountType;
        
        FETCH NEXT FROM movement_cursor INTO 
            @AccountType, @MovementType, @Amount, @SourceAccount, @DestinationAccount, @Description;
    END;
    
    CLOSE movement_cursor;
    DEALLOCATE movement_cursor;
    
    -- CRITICAL: CHECK FOR DEFICITS AT END OF DAY
    
    DECLARE @DebtsBalance DECIMAL(12,2);
    DECLARE @OperationsBalance DECIMAL(12,2);
    DECLARE @ProfitsBalance DECIMAL(12,2);
    
    SELECT @DebtsBalance = Balance FROM #CurrentBalances WHERE AccountType = 'Debts';
    SELECT @OperationsBalance = Balance FROM #CurrentBalances WHERE AccountType = 'Operations';
    SELECT @ProfitsBalance = Balance FROM #CurrentBalances WHERE AccountType = 'Profits';
    
    -- Fix Debts deficit
    IF @DebtsBalance < 0
    BEGIN
        DECLARE @DebtsDeficit DECIMAL(12,2) = ABS(@DebtsBalance);
        DECLARE @DebtsCorrectionAmount DECIMAL(12,2) = (@DebtsDeficit * 1.10) + 1000;
        
        -- Operations → Debts
        INSERT INTO dbo.FactCashMovements (
            MovementDateKey, AccountType, MovementType, Amount,
            SourceAccount, DestinationAccount, Description, RunningBalance
        )
        VALUES 
            (@DateKey, 'Operations', 'Transfer', @DebtsCorrectionAmount,
             'Operations', 'Debts', 'Deficit correction to Debts',
             @OperationsBalance - @DebtsCorrectionAmount),
            (@DateKey, 'Debts', 'Transfer', @DebtsCorrectionAmount,
             'Operations', 'Debts', 'Receive deficit correction',
             @DebtsBalance + @DebtsCorrectionAmount);
        
        UPDATE #CurrentBalances SET Balance = @DebtsBalance + @DebtsCorrectionAmount WHERE AccountType = 'Debts';
        UPDATE #CurrentBalances SET Balance = @OperationsBalance - @DebtsCorrectionAmount WHERE AccountType = 'Operations';
        
        -- Re-read balances
        SELECT @OperationsBalance = Balance FROM #CurrentBalances WHERE AccountType = 'Operations';
        
        PRINT '  Debts deficit corrected: ₦' + CAST(@DebtsCorrectionAmount AS VARCHAR(20));
    END
    
    -- Fix Operations deficit
    IF @OperationsBalance < 0
    BEGIN
        DECLARE @OpsDeficit DECIMAL(12,2) = ABS(@OperationsBalance);
        DECLARE @OpsCorrectionAmount DECIMAL(12,2) = (@OpsDeficit * 1.10) + 1000;
        
        -- Profits → Operations
        INSERT INTO dbo.FactCashMovements (
            MovementDateKey, AccountType, MovementType, Amount,
            SourceAccount, DestinationAccount, Description, RunningBalance
        )
        VALUES 
            (@DateKey, 'Profits', 'Transfer', @OpsCorrectionAmount,
             'Profits', 'Operations', 'Deficit correction to Operations',
             @ProfitsBalance - @OpsCorrectionAmount),
            (@DateKey, 'Operations', 'Transfer', @OpsCorrectionAmount,
             'Profits', 'Operations', 'Receive deficit correction',
             @OperationsBalance + @OpsCorrectionAmount);
        
        UPDATE #CurrentBalances SET Balance = @OperationsBalance + @OpsCorrectionAmount WHERE AccountType = 'Operations';
        UPDATE #CurrentBalances SET Balance = @ProfitsBalance - @OpsCorrectionAmount WHERE AccountType = 'Profits';
        
        PRINT '  Operations deficit corrected: ₦' + CAST(@OpsCorrectionAmount AS VARCHAR(20));
    END
    
    FETCH NEXT FROM date_cursor INTO @ProcessDate, @DateKey;
END;

CLOSE date_cursor;
DEALLOCATE date_cursor;

DROP TABLE #CurrentBalances;
DROP TABLE #DailyMovements;

PRINT 'Daily processing complete with deficit prevention';
GO

-- STEP 5: YEAR-END SWEEPS

DECLARE @YearEndDate INT = 20241231;
DECLARE @YearEndDebts DECIMAL(12,2);
DECLARE @YearEndOperations DECIMAL(12,2);
DECLARE @YearEndProfits DECIMAL(12,2);

SELECT 
    @YearEndDebts = MAX(CASE WHEN AccountType = 'Debts' THEN RunningBalance ELSE 0 END),
    @YearEndOperations = MAX(CASE WHEN AccountType = 'Operations' THEN RunningBalance ELSE 0 END),
    @YearEndProfits = MAX(CASE WHEN AccountType = 'Profits' THEN RunningBalance ELSE 0 END)
FROM dbo.FactCashMovements
WHERE MovementDateKey = @YearEndDate;

PRINT 'Year-end balances before sweeps:';
PRINT '  Debts: ₦' + CAST(@YearEndDebts AS VARCHAR(20));
PRINT '  Operations: ₦' + CAST(@YearEndOperations AS VARCHAR(20));
PRINT '  Profits: ₦' + CAST(@YearEndProfits AS VARCHAR(20));

-- Transfer ALL Debts to Profits
IF @YearEndDebts > 0
BEGIN
    INSERT INTO dbo.FactCashMovements (
        MovementDateKey, AccountType, MovementType, Amount,
        SourceAccount, DestinationAccount, Description, RunningBalance
    )
    VALUES 
        (@YearEndDate, 'Debts', 'Transfer', @YearEndDebts,
         'Debts', 'Profits', 'Year-end sweep: Debts → Profits', 0.00),
        (@YearEndDate, 'Profits', 'Transfer', @YearEndDebts,
         'Debts', 'Profits', 'Year-end sweep: Receive from Debts', 
         @YearEndProfits + @YearEndDebts);
    
    SET @YearEndProfits = @YearEndProfits + @YearEndDebts;
END

-- Transfer Operations excess if > ₦500K
IF @YearEndOperations > 500000
BEGIN
    DECLARE @TransferAmount DECIMAL(12,2) = @YearEndOperations - 500000;
    
    INSERT INTO dbo.FactCashMovements (
        MovementDateKey, AccountType, MovementType, Amount,
        SourceAccount, DestinationAccount, Description, RunningBalance
    )
    VALUES 
        (@YearEndDate, 'Operations', 'Transfer', @TransferAmount,
         'Operations', 'Profits', 'Year-end sweep: Operations excess → Profits', 500000.00),
        (@YearEndDate, 'Profits', 'Transfer', @TransferAmount,
         'Operations', 'Profits', 'Year-end sweep: Receive from Operations', 
         @YearEndProfits + @TransferAmount);
END

PRINT 'Year-end sweeps complete';
GO

