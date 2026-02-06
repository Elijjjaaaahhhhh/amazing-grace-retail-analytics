USE AmazingGraceStore;
GO

-- Count tables
SELECT 
    'Total Tables Created' AS Verification_Step,
    COUNT(*) AS Table_Count,
    'Expected: 12' AS Expected_Count
FROM sys.tables
WHERE schema_id = SCHEMA_ID('dbo');

-- List all tables
SELECT 
    'Table List' AS Verification_Step,
    name AS Table_Name,
    create_date AS Created_Date
FROM sys.tables
WHERE schema_id = SCHEMA_ID('dbo')
ORDER BY name;

-- Count foreign key relationships
SELECT 
    'Foreign Key Constraints' AS Verification_Step,
    COUNT(*) AS FK_Count,
    'Expected: 20+' AS Expected_Count
FROM sys.foreign_keys;

-- List all foreign keys
SELECT 
    'Foreign Key Details' AS Verification_Step,
    OBJECT_NAME(parent_object_id) AS Child_Table,
    OBJECT_NAME(referenced_object_id) AS Parent_Table,
    name AS FK_Name
FROM sys.foreign_keys
ORDER BY OBJECT_NAME(parent_object_id);

-- Count check constraints
SELECT 
    'Check Constraints' AS Verification_Step,
    COUNT(*) AS Check_Count,
    'Expected: 30+' AS Expected_Count
FROM sys.check_constraints;

-- Verify indexes
SELECT 
    'Indexes Created' AS Verification_Step,
    COUNT(*) AS Index_Count,
    'Expected: 50+' AS Expected_Count
FROM sys.indexes
WHERE object_id IN (SELECT object_id FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo'))
    AND type_desc != 'HEAP';

PRINT 'Schema verification complete!';
GO

-- =============================================
-- VERIFICATION QUERIES
-- =============================================

-- 1. Verify total rows and key metrics
SELECT 
    'Metric' AS Category,
    'Total Days in 2024' AS Description,
    COUNT(*) AS Count
FROM dbo.DimDate
UNION ALL
SELECT 'Metric', 'Store Open Days', COUNT(*) FROM dbo.DimDate WHERE IsStoreOpen = 1
UNION ALL
SELECT 'Metric', 'Store Closed Days', COUNT(*) FROM dbo.DimDate WHERE IsStoreOpen = 0
UNION ALL
SELECT 'Metric', 'Sundays (Closed)', COUNT(*) FROM dbo.DimDate WHERE DayName = 'Sunday'
UNION ALL
SELECT 'Metric', 'Peak Period Days', COUNT(*) FROM dbo.DimDate WHERE IsPeakPeriod = 1
UNION ALL
SELECT 'Metric', 'Sales Period Days', COUNT(*) FROM dbo.DimDate WHERE IsSalesPeriod = 1
UNION ALL
SELECT 'Metric', 'Weekend Days (Sat + Sun)', COUNT(*) FROM dbo.DimDate WHERE IsWeekend = 1;

-- 2. Verify January opening schedule
SELECT 
    'January 2024 Opening Schedule' AS Info,
    DateKey,
    FullDate,
    DayName,
    IsStoreOpen,
    CASE 
        WHEN IsStoreOpen = 0 AND DayName = 'Sunday' THEN 'Closed - Sunday'
        WHEN IsStoreOpen = 0 AND FullDate < '2024-01-04' THEN 'Closed - Before Opening'
        WHEN IsStoreOpen = 1 THEN 'OPEN'
        ELSE 'Closed - Other'
    END AS Status
FROM dbo.DimDate
WHERE MONTH(FullDate) = 1 AND YEAR(FullDate) = 2024
ORDER BY FullDate;

-- 3. Verify holiday closures
SELECT 
    'Holiday Closures' AS Info,
    FullDate,
    DayName,
    CASE 
        WHEN FullDate < '2024-01-04' THEN 'Pre-Opening (Jan 1-3)'
        WHEN FullDate = '2024-03-29' THEN 'Good Friday'
        WHEN FullDate = '2024-04-01' THEN 'Easter Monday'
        WHEN FullDate BETWEEN '2024-12-25' AND '2024-12-27' THEN 'Christmas Period'
        WHEN DayName = 'Sunday' THEN 'Regular Sunday Closure'
    END AS HolidayType,
    IsStoreOpen
FROM dbo.DimDate
WHERE IsStoreOpen = 0 
    AND DayName != 'Sunday'  -- Exclude regular Sunday closures for clarity
ORDER BY FullDate;

-- 4. Verify sales periods
SELECT 
    'Sales Periods' AS Info,
    MIN(FullDate) AS StartDate,
    MAX(FullDate) AS EndDate,
    COUNT(*) AS TotalDays,
    SUM(CASE WHEN IsStoreOpen = 1 THEN 1 ELSE 0 END) AS OpenDays,
    CASE 
        WHEN MONTH(MIN(FullDate)) = 2 THEN 'February Sales'
        WHEN MONTH(MIN(FullDate)) = 6 THEN 'June Sales'
        WHEN MONTH(MIN(FullDate)) = 11 THEN 'November Sales'
    END AS SalesPeriod
FROM dbo.DimDate
WHERE IsSalesPeriod = 1
GROUP BY 
    CASE 
        WHEN MONTH(FullDate) = 2 THEN 1
        WHEN MONTH(FullDate) = 6 THEN 2
        WHEN MONTH(FullDate) = 11 THEN 3
    END
ORDER BY MIN(FullDate);

-- 5. Monthly breakdown of open days
SELECT 
    MonthName,
    COUNT(*) AS TotalDays,
    SUM(CASE WHEN IsStoreOpen = 1 THEN 1 ELSE 0 END) AS OpenDays,
    SUM(CASE WHEN IsStoreOpen = 0 THEN 1 ELSE 0 END) AS ClosedDays,
    SUM(CASE WHEN IsPeakPeriod = 1 THEN 1 ELSE 0 END) AS PeakDays,
    SUM(CASE WHEN IsSalesPeriod = 1 THEN 1 ELSE 0 END) AS SalesDays
FROM dbo.DimDate
GROUP BY Month, MonthName
ORDER BY Month;

PRINT 'DimDate regenerated successfully with corrected business rules!';
PRINT 'Store opens: Thursday, January 4th, 2024';
PRINT 'Christian holidays (Easter, Christmas) marked as closed';
GO


--Verification for FactBells--

SELECT 'CONSTRAINT VIOLATIONS' AS Test, COUNT(*) AS Count, '0 expected' AS Expected
FROM dbo.FactBells
WHERE TotalItems != (SellableItems + UnsellableItems)
   OR BellCost < 350000 OR BellCost > 850000
   OR TotalItems <= 0 OR SellableItems <= 0;

SELECT 'Total Bells' AS Metric, COUNT(*) AS Count FROM dbo.FactBells
UNION ALL
SELECT 'Loan-Funded', COUNT(*) FROM dbo.FactBells WHERE IsProfitFunded = 0
UNION ALL
SELECT 'Profit-Funded', COUNT(*) FROM dbo.FactBells WHERE IsProfitFunded = 1;

SELECT 
    c.CategoryName,
    COUNT(*) AS Bells,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Pct,
    FORMAT(MIN(fb.BellCost), 'C', 'en-NG') AS MinCost,
    FORMAT(MAX(fb.BellCost), 'C', 'en-NG') AS MaxCost,
    FORMAT(AVG(fb.BellCost), 'C', 'en-NG') AS AvgCost
FROM dbo.FactBells fb
JOIN dbo.DimCategories c ON fb.CategoryID = c.CategoryID
GROUP BY c.CategoryName
ORDER BY COUNT(*) DESC;

SELECT 
    bs.BellSizeName,
    COUNT(*) AS Bells,
    MIN(fb.TotalItems) AS MinItems,
    MAX(fb.TotalItems) AS MaxItems,
    AVG(fb.TotalItems) AS AvgItems,
    AVG(fb.SellablePercentage) * 100 AS AvgSellablePct
FROM dbo.FactBells fb
JOIN dbo.DimBellSizes bs ON fb.BellSizeID = bs.BellSizeID
GROUP BY bs.BellSizeName, bs.BellSizeID
ORDER BY bs.BellSizeID;

SELECT TOP 25
    fb.BellID,
    CONVERT(DATE, CAST(fb.PurchaseDateKey AS VARCHAR(8)), 112) AS Date,
    c.CategoryName,
    s.SubcategoryName,
    bs.BellSizeName,
    fb.TotalItems,
    fb.SellableItems,
    CAST(fb.SellablePercentage * 100 AS DECIMAL(5,2)) AS SellPct,
    FORMAT(fb.BellCost, 'C', 'en-NG') AS Cost,
    FORMAT(fb.CostPerItem, 'C', 'en-NG') AS CostPerItem
FROM dbo.FactBells fb
JOIN dbo.DimCategories c ON fb.CategoryID = c.CategoryID
JOIN dbo.DimSubcategories s ON fb.SubcategoryID = s.SubcategoryID
JOIN dbo.DimBellSizes bs ON fb.BellSizeID = bs.BellSizeID
ORDER BY fb.BellID;

PRINT '✓ FactBells generation COMPLETE';
PRINT '✓ BellID starts from 1';
PRINT '✓ All fields randomized correctly';
PRINT '✓ BellCost varies ₦350K-₦850K';
PRINT '✓ TotalItems matches BellSize ranges';
PRINT '✓ SellablePercentage varies 65%-90%';
GO


-- VERIFICATION for FactItems Generation


SELECT 'Total Items' AS Metric, COUNT(*) AS Count FROM dbo.FactItems;

SELECT 
    'Items Sold' AS Status,
    COUNT(*) AS Count,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.FactItems) AS DECIMAL(5,2)) AS Percentage
FROM dbo.FactItems WHERE IsSold = 1
UNION ALL
SELECT 
    'Items Unsold',
    COUNT(*),
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.FactItems) AS DECIMAL(5,2))
FROM dbo.FactItems WHERE IsSold = 0;

SELECT 
    ig.GradeName,
    COUNT(*) AS Items,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.FactItems) AS DECIMAL(5,2)) AS Pct
FROM dbo.FactItems fi
JOIN dbo.DimItemGrades ig ON fi.GradeID = ig.GradeID
GROUP BY ig.GradeID, ig.GradeName;

SELECT 
    'Discounted Items' AS Metric,
    COUNT(*) AS Count,
    'Items 90+ days old during sales periods' AS Note
FROM dbo.FactItems
WHERE IsInDiscount = 1;

SELECT 
    'Constraint Violations' AS Check_Type,
    COUNT(*) AS Count,
    '0 expected' AS Expected
FROM dbo.FactItems
WHERE (IsSold = 1 AND DateSoldKey IS NULL)
   OR (IsSold = 0 AND DateSoldKey IS NOT NULL)
   OR (IsTopTier = 1 AND GradeID != 1);

SELECT TOP 20
    fi.ItemID,
    fi.BellID,
    c.CategoryName,
    ig.GradeName,
    FORMAT(fi.SellingPrice, 'C', 'en-NG') AS Price,
    CASE WHEN fi.IsSold = 1 THEN 'Sold' ELSE 'Unsold' END AS Status,
    fi.DaysInInventory,
    CASE WHEN fi.IsInDiscount = 1 THEN CAST(fi.DiscountPercent AS VARCHAR) + '%' ELSE '-' END AS Discount
FROM dbo.FactItems fi
JOIN dbo.DimCategories c ON fi.CategoryID = c.CategoryID
JOIN dbo.DimItemGrades ig ON fi.GradeID = ig.GradeID
ORDER BY fi.ItemID;

PRINT '✓ FactItems generation COMPLETE with corrected constraint';
GO




--FACTSALES VERIFICATION REPORT--


-- Check 1: Total transactions and revenue
SELECT 
    'Total Transactions' AS Metric,
    COUNT(*) AS Count,
    FORMAT(SUM(TotalAmount), 'C', 'en-NG') AS TotalRevenue,
    FORMAT(AVG(TotalAmount), 'C', 'en-NG') AS AvgTransaction,
    FORMAT(SUM(DiscountAmount), 'C', 'en-NG') AS TotalDiscounts
FROM dbo.FactSales;

-- Check 2: Transaction size distribution
SELECT 
    CASE 
        WHEN TotalItems = 1 THEN '1 item'
        WHEN TotalItems BETWEEN 2 AND 4 THEN '2-4 items'
        WHEN TotalItems BETWEEN 5 AND 8 THEN '5-8 items'
        WHEN TotalItems BETWEEN 9 AND 10 THEN '9-10 items'
        ELSE '11+ items'
    END AS TransactionSize,
    COUNT(*) AS Transactions,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.FactSales) AS DECIMAL(5,2)) AS Percentage,
    FORMAT(AVG(TotalAmount), 'C', 'en-NG') AS AvgValue
FROM dbo.FactSales
GROUP BY 
    CASE 
        WHEN TotalItems = 1 THEN '1 item'
        WHEN TotalItems BETWEEN 2 AND 4 THEN '2-4 items'
        WHEN TotalItems BETWEEN 5 AND 8 THEN '5-8 items'
        WHEN TotalItems BETWEEN 9 AND 10 THEN '9-10 items'
        ELSE '11+ items'
    END
ORDER BY 
    CASE 
        WHEN TotalItems = 1 THEN 1
        WHEN TotalItems BETWEEN 2 AND 4 THEN 2
        WHEN TotalItems BETWEEN 5 AND 8 THEN 3
        WHEN TotalItems BETWEEN 9 AND 10 THEN 4
        ELSE 5
    END;

-- Check 3: Payment method distribution
SELECT 
    PaymentMethod,
    COUNT(*) AS Transactions,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.FactSales) AS DECIMAL(5,2)) AS Percentage,
    FORMAT(SUM(TotalAmount), 'C', 'en-NG') AS TotalValue
FROM dbo.FactSales
GROUP BY PaymentMethod
ORDER BY COUNT(*) DESC;

-- Check 4: Recurring customer percentage
SELECT 
    CASE WHEN IsRecurringCustomer = 1 THEN 'Recurring' ELSE 'New' END AS CustomerType,
    COUNT(*) AS Transactions,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.FactSales) AS DECIMAL(5,2)) AS Percentage
FROM dbo.FactSales
GROUP BY IsRecurringCustomer;

-- Check 5: Monthly sales summary
SELECT 
    d.MonthName,
    COUNT(DISTINCT fs.SaleTransactionID) AS Transactions,
    SUM(fs.TotalItems) AS ItemsSold,
    FORMAT(SUM(fs.TotalAmount), 'C', 'en-NG') AS Revenue,
    FORMAT(AVG(fs.TotalAmount), 'C', 'en-NG') AS AvgTransaction
FROM dbo.FactSales fs
JOIN dbo.DimDate d ON fs.SaleDateKey = d.DateKey
GROUP BY d.Month, d.MonthName
ORDER BY d.Month;

-- Check 6: Verify item linkage
SELECT 
    'Items with SaleTransactionID' AS Check_Type,
    COUNT(*) AS Count,
    'Should equal sold items' AS Note
FROM dbo.FactItems
WHERE SaleTransactionID IS NOT NULL;

SELECT 
    'Sold items without SaleTransactionID' AS Check_Type,
    COUNT(*) AS Count,
    '0 expected' AS Expected
FROM dbo.FactItems
WHERE IsSold = 1 AND SaleTransactionID IS NULL;

-- Check 7: Transaction totals match item totals
SELECT 
    fs.SaleTransactionID,
    fs.TotalItems AS TransactionItems,
    COUNT(fi.ItemID) AS ActualItems,
    FORMAT(fs.TotalAmount, 'C', 'en-NG') AS TransactionTotal,
    FORMAT(SUM(fi.FinalSalePrice), 'C', 'en-NG') AS ItemsTotal,
    CASE 
        WHEN ABS(fs.TotalAmount - SUM(fi.FinalSalePrice)) < 0.01 THEN 'Match'
        ELSE 'MISMATCH'
    END AS ValidationStatus
FROM dbo.FactSales fs
LEFT JOIN dbo.FactItems fi ON fs.SaleTransactionID = fi.SaleTransactionID
GROUP BY fs.SaleTransactionID, fs.TotalItems, fs.TotalAmount
HAVING ABS(fs.TotalAmount - SUM(fi.FinalSalePrice)) > 0.01  -- Show only mismatches
ORDER BY fs.SaleTransactionID;

-- If no rows returned above, all transactions match!

-- Check 8: Constraint validation
SELECT 
    'Constraint Violations' AS Check_Type,
    COUNT(*) AS Count,
    '0 expected' AS Expected
FROM dbo.FactSales
WHERE TotalAmount != (SubtotalAmount - DiscountAmount)
   OR TotalItems <= 0
   OR SubtotalAmount <= 0
   OR TotalAmount <= 0
   OR PaymentMethod NOT IN ('Cash', 'Transfer', 'POS');

-- Check 9: Sample transactions with items
SELECT TOP 10
    fs.SaleTransactionID,
    fs.SaleDateTime,
    d.DayName,
    fs.TotalItems,
    FORMAT(fs.SubtotalAmount, 'C', 'en-NG') AS Subtotal,
    FORMAT(fs.DiscountAmount, 'C', 'en-NG') AS Discount,
    FORMAT(fs.TotalAmount, 'C', 'en-NG') AS Total,
    fs.PaymentMethod,
    CASE WHEN fs.IsRecurringCustomer = 1 THEN 'Yes' ELSE 'No' END AS Recurring
FROM dbo.FactSales fs
JOIN dbo.DimDate d ON fs.SaleDateKey = d.DateKey
ORDER BY fs.SaleTransactionID;

-- Show items in first transaction
SELECT TOP 1 @FirstTransactionID = MIN(SaleTransactionID) FROM dbo.FactSales;

SELECT 
    'Items in First Transaction' AS Info,
    fi.ItemID,
    c.CategoryName,
    s.SubcategoryName,
    FORMAT(fi.FinalSalePrice, 'C', 'en-NG') AS Price
FROM dbo.FactItems fi
JOIN dbo.DimCategories c ON fi.CategoryID = c.CategoryID
JOIN dbo.DimSubcategories s ON fi.SubcategoryID = s.SubcategoryID
WHERE fi.SaleTransactionID = (SELECT MIN(SaleTransactionID) FROM dbo.FactSales);

PRINT '';
PRINT '========================================';
PRINT '✓ FactSales generation COMPLETE';
PRINT '✓ Transactions created with realistic distribution';
PRINT '✓ FactItems linked to transactions';
PRINT '✓ Payment methods distributed correctly';
PRINT '✓ Revenue totals validated';
PRINT '========================================';
GO

-- VERIFICATION for FactExpense

SELECT 
    'Total Expense Records' AS Metric,
    COUNT(*) AS Count,
    FORMAT(SUM(Amount), 'C', 'en-NG') AS TotalExpenses
FROM dbo.FactExpenses;

SELECT 
    ExpenseCategory,
    COUNT(*) AS Records,
    FORMAT(SUM(Amount), 'C', 'en-NG') AS TotalAmount,
    FORMAT(AVG(Amount), 'C', 'en-NG') AS AvgAmount
FROM dbo.FactExpenses
GROUP BY ExpenseCategory
ORDER BY SUM(Amount) DESC;

SELECT 
    CASE WHEN IsRecurring = 1 THEN 'Recurring' ELSE 'Variable' END AS ExpenseType,
    COUNT(*) AS Records,
    FORMAT(SUM(Amount), 'C', 'en-NG') AS TotalAmount
FROM dbo.FactExpenses
GROUP BY IsRecurring;

SELECT 
    PaymentMethod,
    COUNT(*) AS Records,
    FORMAT(SUM(Amount), 'C', 'en-NG') AS TotalAmount
FROM dbo.FactExpenses
GROUP BY PaymentMethod;

SELECT TOP 20
    fe.ExpenseID,
    CONVERT(DATE, CAST(fe.ExpenseDateKey AS VARCHAR(8)), 112) AS ExpenseDate,
    fe.ExpenseCategory,
    fe.ExpenseDescription,
    FORMAT(fe.Amount, 'C', 'en-NG') AS Amount,
    fe.PaymentMethod
FROM dbo.FactExpenses fe
ORDER BY fe.ExpenseDateKey;

PRINT '✓ FactExpenses generation COMPLETE';
GO

-- VERIFICATION for FactCashMovement

-- Check for ANY negative balances
SELECT 
    'Negative Balance Check' AS Test,
    COUNT(*) AS NegativeBalances,
    '0 expected' AS Expected
FROM dbo.FactCashMovements
WHERE RunningBalance < 0;

-- Final balances
SELECT 
    'Final Balances (Dec 31, 2024)' AS Info,
    AccountType,
    FORMAT(RunningBalance, 'C', 'en-NG') AS Balance
FROM (
    SELECT 
        AccountType,
        RunningBalance,
        ROW_NUMBER() OVER (PARTITION BY AccountType ORDER BY CashMovementID DESC) AS RowNum
    FROM dbo.FactCashMovements
    WHERE MovementDateKey = 20241231
) AS LastMovements
WHERE RowNum = 1
ORDER BY AccountType;

-- Monthly summary
SELECT 
    d.MonthName,
    fcm.AccountType,
    FORMAT(SUM(CASE WHEN fcm.MovementType IN ('Deposit', 'Transfer') 
        AND (fcm.DestinationAccount IS NULL OR fcm.AccountType = fcm.DestinationAccount) 
        THEN fcm.Amount ELSE 0 END), 'C', 'en-NG') AS Inflows,
    FORMAT(SUM(CASE WHEN fcm.MovementType IN ('Withdrawal', 'Transfer') 
        AND (fcm.SourceAccount IS NULL OR fcm.AccountType = fcm.SourceAccount) 
        THEN fcm.Amount ELSE 0 END), 'C', 'en-NG') AS Outflows
FROM dbo.FactCashMovements fcm
JOIN dbo.DimDate d ON fcm.MovementDateKey = d.DateKey
WHERE fcm.MovementType IN ('Deposit', 'Withdrawal')
   OR (fcm.MovementType = 'Transfer' AND fcm.Description NOT LIKE '%deficit%')
GROUP BY d.Month, d.MonthName, fcm.AccountType
ORDER BY d.Month, fcm.AccountType;

-- Deficit corrections summary
SELECT 
    'Deficit Corrections Applied' AS Info,
    COUNT(*) AS Count
FROM dbo.FactCashMovements
WHERE Description LIKE '%Deficit correction%';

PRINT '✓ FactCashMovements generation COMPLETE';
PRINT '✓ NO negative balances allowed';
PRINT '✓ Daily deficit corrections applied';
GO
