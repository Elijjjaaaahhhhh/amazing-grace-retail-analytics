USE AmazingGraceStore;
GO

SET IDENTITY_INSERT dbo.DimCategories ON;
GO

INSERT INTO dbo.DimCategories (CategoryID, CategoryName, CategoryDescription)
VALUES
    (1, 'Tops', 'Upper body wear including shirts, blouses, and tank tops'),
    (2, 'Bottoms', 'Lower body wear including jeans, trousers, and shorts'),
    (3, 'Outerwear', 'Jackets, blazers, hoodies, and vests'),
    (4, 'Activewear/Sportswear', 'Gym wear, track pants, and performance clothing'),
    (5, 'Dresses & One-Piece', 'Dresses, gowns, jumpsuits, and rompers');
GO

SET IDENTITY_INSERT dbo.DimCategories OFF;
GO

-- Verify insert
SELECT CategoryID, CategoryName, CategoryDescription 
FROM dbo.DimCategories 
ORDER BY CategoryID;

PRINT 'DimCategories populated: 5 rows inserted';
GO

-- =============================================
-- ALTER TABLE: Add Gender column
-- =============================================

USE AmazingGraceStore;
GO

ALTER TABLE dbo.DimSubcategories
ADD Gender NVARCHAR(10) NOT NULL DEFAULT('Both')
    CONSTRAINT CK_DimSubcategories_Gender 
    CHECK (Gender IN ('Male', 'Female', 'Both'));
GO

PRINT 'Gender column added to DimSubcategories';
GO

SET IDENTITY_INSERT dbo.DimSubcategories ON;
GO

INSERT INTO dbo.DimSubcategories 
    (SubcategoryID, CategoryID, SubcategoryName, IsFastMoving, Gender)
VALUES
    -- CATEGORY 1: Tops (25% of inventory)
    (1,  1, 'T-shirts (graphic)', 1, 'Both'),
    (2,  1, 'T-shirts (plain)', 1, 'Both'),
    (3,  1, 'T-shirts (oversized)', 1, 'Both'),
    (4,  1, 'Polo shirts', 0, 'Both'),
    (5,  1, 'Shirts (formal)', 0, 'Both'),
    (6,  1, 'Shirts (casual)', 0, 'Both'),
    (7,  1, 'Shirts (flannel)', 1, 'Both'),
    (8,  1, 'Crop tops', 0, 'Female'),
    (9,  1, 'Tank tops', 0, 'Both'),
    (10, 1, 'Blouses', 0, 'Female'),
    
    -- CATEGORY 2: Bottoms (30% of inventory)
    (11, 2, 'Jeans (skinny)', 0, 'Both'),
    (12, 2, 'Jeans (straight)', 0, 'Both'),
    (13, 2, 'Jeans (bootcut)', 0, 'Both'),
    (14, 2, 'Jeans (baggy)', 1, 'Both'),
    (15, 2, 'Joggers', 1, 'Both'),
    (16, 2, 'Trousers/slacks (corporate)', 1, 'Both'),
    (17, 2, 'Trousers/slacks (casual)', 0, 'Both'),
    (18, 2, 'Chinos', 0, 'Both'),
    (19, 2, 'Shorts (cargo)', 1, 'Male'),
    (20, 2, 'Shorts (denim)', 1, 'Both'),
    (21, 2, 'Shorts (athletic)', 1, 'Both'),
    (22, 2, 'Leggings', 0, 'Female'),
    
    -- CATEGORY 3: Outerwear (15% of inventory)
    (23, 3, 'Jackets (denim)', 0, 'Both'),
    (24, 3, 'Jackets (leather)', 0, 'Both'),
    (25, 3, 'Blazers', 0, 'Both'),
    (26, 3, 'Hoodies', 0, 'Both'),
    (27, 3, 'Sweatshirts', 1, 'Both'),
    (28, 3, 'Windbreakers', 0, 'Both'),
    (29, 3, 'Vests/gilets', 0, 'Both'),
    
    -- CATEGORY 4: Activewear/Sportswear (20% of inventory)
    (30, 4, 'Gym tops', 0, 'Both'),
    (31, 4, 'Sports bras', 0, 'Female'),
    (32, 4, 'Track pants', 1, 'Both'),
    (33, 4, 'Performance shorts', 0, 'Both'),
    (34, 4, 'Yoga wear', 0, 'Female'),
    (35, 4, 'Compression wear', 0, 'Both'),
    (36, 4, 'Jerseys', 1, 'Both'),
    (37, 4, 'Sweats (top)', 1, 'Both'),
    (38, 4, 'Sweats (bottom)', 1, 'Both'),
    
    -- CATEGORY 5: Dresses & One-Piece (10% of inventory)
    (39, 5, 'Casual dresses', 0, 'Female'),
    (40, 5, 'Bodycon dresses', 0, 'Female'),
    (41, 5, 'Shirt dresses', 0, 'Female'),
    (42, 5, 'Formal dresses', 0, 'Female'),
    (43, 5, 'Evening dresses', 0, 'Female'),
    (44, 5, 'Gowns', 0, 'Female'),
    (45, 5, 'Jumpsuits', 0, 'Female'),
    (46, 5, 'Playsuits', 0, 'Female'),
    (47, 5, 'Rompers', 0, 'Female');
GO

SET IDENTITY_INSERT dbo.DimSubcategories OFF;
GO

-- Verify insert
SELECT 
    s.SubcategoryID,
    c.CategoryName,
    s.SubcategoryName,
    s.IsFastMoving,
    s.Gender
FROM dbo.DimSubcategories s
JOIN dbo.DimCategories c ON s.CategoryID = c.CategoryID
ORDER BY s.CategoryID, s.SubcategoryID;

-- Summary statistics
SELECT 
    'Total Subcategories' AS Metric,
    COUNT(*) AS Count
FROM dbo.DimSubcategories
UNION ALL
SELECT 
    'Fast-Moving Items',
    COUNT(*)
FROM dbo.DimSubcategories
WHERE IsFastMoving = 1
UNION ALL
SELECT 
    'Male-Specific Items',
    COUNT(*)
FROM dbo.DimSubcategories
WHERE Gender = 'Male'
UNION ALL
SELECT 
    'Female-Specific Items',
    COUNT(*)
FROM dbo.DimSubcategories
WHERE Gender = 'Female'
UNION ALL
SELECT 
    'Gender-Neutral Items',
    COUNT(*)
FROM dbo.DimSubcategories
WHERE Gender = 'Both';

PRINT 'DimSubcategories populated: 47 rows inserted';
GO


SET IDENTITY_INSERT dbo.DimBellSizes ON;
GO

INSERT INTO dbo.DimBellSizes (BellSizeID, BellSizeName, MinItems, MaxItems)
VALUES
    (1, 'Small', 200, 250),
    (2, 'Medium', 300, 350),
    (3, 'Large', 400, 500);
GO

SET IDENTITY_INSERT dbo.DimBellSizes OFF;
GO

-- Verify insert
SELECT BellSizeID, BellSizeName, MinItems, MaxItems,
       (MaxItems - MinItems) AS ItemRange
FROM dbo.DimBellSizes
ORDER BY BellSizeID;

PRINT 'DimBellSizes populated: 3 rows inserted';
GO


INSERT INTO dbo.DimItemGrades (GradeID, GradeName, CanBeTopTier)
VALUES
    (1, 'Grade 1', 1),
    (2, 'Grade 2', 0);
GO

-- Verify insert
SELECT GradeID, GradeName, CanBeTopTier,
       CASE WHEN CanBeTopTier = 1 THEN 'Eligible for 50% markup' 
            ELSE 'Max 30% markup' END AS TopTierStatus
FROM dbo.DimItemGrades
ORDER BY GradeID;

PRINT 'DimItemGrades populated: 2 rows inserted';
GO


-- Verify January 2024 calendar
SELECT 
    'January 2024 Calendar Check' AS Info,
    DATENAME(WEEKDAY, '2024-01-01') AS Jan1DayOfWeek,
    DATENAME(WEEKDAY, '2024-01-04') AS Jan4DayOfWeek;
-- Expected: Jan 1 = Monday, Jan 4 = Thursday

DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate DATE = '2024-12-31';

;WITH DateSequence AS (
    SELECT @StartDate AS FullDate
    UNION ALL
    SELECT DATEADD(DAY, 1, FullDate)
    FROM DateSequence
    WHERE FullDate < @EndDate
)
INSERT INTO dbo.DimDate 
(
    DateKey, FullDate, Year, Month, MonthName, Quarter, WeekOfYear, 
    DayOfWeek, DayName, IsWeekend, IsStoreOpen, IsPeakPeriod, 
    IsSalesPeriod, FiscalYear, FiscalMonth
)
SELECT 
    CAST(FORMAT(FullDate, 'yyyyMMdd') AS INT) AS DateKey,
    FullDate,
    YEAR(FullDate) AS Year,
    MONTH(FullDate) AS Month,
    DATENAME(MONTH, FullDate) AS MonthName,
    DATEPART(QUARTER, FullDate) AS Quarter,
    DATEPART(WEEK, FullDate) AS WeekOfYear,
    
    -- DayOfWeek: 1=Sunday, 2=Monday, ..., 7=Saturday (SQL Server default)
    -- We'll use DATEPART(WEEKDAY) which follows server setting
    DATEPART(WEEKDAY, FullDate) AS DayOfWeek,
    DATENAME(WEEKDAY, FullDate) AS DayName,
    
    -- IsWeekend: Saturday or Sunday
    CASE WHEN DATENAME(WEEKDAY, FullDate) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END AS IsWeekend,
    
    -- IsStoreOpen: Complex logic
    CASE 
        -- Closed on Sundays
        WHEN DATENAME(WEEKDAY, FullDate) = 'Sunday' THEN 0
        
        -- Closed Jan 1-3, 2024 (before opening)
        WHEN FullDate < '2024-01-04' THEN 0
        
        -- Closed Good Friday (March 29, 2024)
        WHEN FullDate = '2024-03-29' THEN 0
        
        -- Closed Easter Monday (April 1, 2024)
        WHEN FullDate = '2024-04-01' THEN 0
        
        -- Closed Christmas period (Dec 25-27, 2024)
        WHEN FullDate BETWEEN '2024-12-25' AND '2024-12-27' THEN 0
        
        -- Otherwise open Monday-Saturday
        ELSE 1
    END AS IsStoreOpen,
    
    -- Peak Period Logic
    CASE 
        -- December (holiday season)
        WHEN MONTH(FullDate) = 12 THEN 1
        
        -- End of month (25th onwards - payday shopping)
        WHEN DAY(FullDate) >= 25 THEN 1
        
        -- Mid-term break (April 15-28)
        WHEN (MONTH(FullDate) = 4 AND DAY(FullDate) BETWEEN 15 AND 28) THEN 1
        
        -- Summer holidays (July 15 - September 10)
        WHEN (MONTH(FullDate) = 7 AND DAY(FullDate) >= 15) THEN 1
        WHEN (MONTH(FullDate) = 8) THEN 1
        WHEN (MONTH(FullDate) = 9 AND DAY(FullDate) <= 10) THEN 1
        
        -- University resumption (Jan 8-20)
        WHEN (MONTH(FullDate) = 1 AND DAY(FullDate) BETWEEN 8 AND 20) THEN 1
        
        -- University resumption (Sept 5-20)
        WHEN (MONTH(FullDate) = 9 AND DAY(FullDate) BETWEEN 5 AND 20) THEN 1
        
        ELSE 0 
    END AS IsPeakPeriod,
    
    -- Sales Period Logic (3-week discount periods)
    CASE 
        -- February sales: 5th-25th (3 weeks)
        WHEN (MONTH(FullDate) = 2 AND DAY(FullDate) BETWEEN 5 AND 25) THEN 1
        
        -- June sales: 3rd-23rd (3 weeks)
        WHEN (MONTH(FullDate) = 6 AND DAY(FullDate) BETWEEN 3 AND 23) THEN 1
        
        -- November sales: 4th-24th (3 weeks)
        WHEN (MONTH(FullDate) = 11 AND DAY(FullDate) BETWEEN 4 AND 24) THEN 1
        
        ELSE 0 
    END AS IsSalesPeriod,
    
    YEAR(FullDate) AS FiscalYear,
    MONTH(FullDate) AS FiscalMonth
FROM DateSequence
OPTION (MAXRECURSION 366);
GO

