# Setup Instructions

## Quick Start Guide

### Prerequisites
- **SQL Server 2022** (or SQL Server 2019+)
- **SSMS** (SQL Server Management Studio)
- **Disk Space:** At least 1GB free
- **Permissions:** Database creation rights on your SQL Server instance

---

## Installation Steps

### Option 1: Execute All Scripts at Once (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/Elijjjaaaahhhhh/amazing-grace-retail-analytics.git
cd amazing-grace-retail-analytics

# 2. Open SSMS and connect to your SQL Server

# 3. Run the complete setup script
# File -> Open -> setup_complete.sql
# Then press F5 to execute

# This will:
# - Create the database
# - Create all tables
# - Populate dimensions
# - Generate ~100K rows of fact data
# - Run verification checks
```

**Estimated time:** 5-10 minutes

---

### Option 2: Step-by-Step Execution

If you prefer to see each step:

#### Step 1: Create Database and Schema
```sql
-- In SSMS, open and execute these files in order:
database/schema/01_create_database.sql
database/schema/02_create_dimensions.sql
database/schema/03_create_facts.sql
```

#### Step 2: Populate Dimension Tables
```sql
database/data/01_populate_dimcategories.sql
database/data/02_populate_dimsubcategories.sql
database/data/03_populate_dimbellsizes.sql
database/data/04_populate_dimitemgrades.sql
database/data/05_generate_dimdate.sql
```

**Verify:** Should see 5 + 47 + 3 + 2 + 366 = 423 dimension rows

#### Step 3: Generate Fact Tables (IN ORDER - Dependencies Matter!)
```sql
database/data/06_generate_factloans.sql           -- 8 loans
database/data/07_generate_factloanrepayments.sql  -- ~70 repayments
database/data/08_generate_factbells.sql           -- ~130 bells (⏱️ 20-30 sec)
database/data/09_generate_factitems.sql           -- ~36,000 items (⏱️ 2-3 min)
database/data/10_generate_factsales.sql           -- ~21,800 sales (⏱️ 1-2 min)
database/data/11_generate_factexpenses.sql        -- ~200 expenses
database/data/12_generate_factcashmovements.sql   -- ~1,200 movements
```

**Why this order matters:**
- FactLoans must exist before FactBells (some bells are loan-funded)
- FactBells must exist before FactItems (items come from bells)
- FactItems must exist before FactSales (sales group sold items)

#### Step 4: Verify Data Quality
```sql
database/verification/verify_all.sql
```

**Expected output:** All checks should show 0 violations

---

## Troubleshooting

### Issue: "Cannot create database"
**Error:** Access denied or file path not found

**Fix:**
```sql
-- Modify the file paths in 01_create_database.sql
-- Change this:
FILENAME = N'C:\Program Files\Microsoft SQL Server\...'

-- To a path you have access to:
FILENAME = N'C:\SQLData\AmazingGraceStore.mdf'
```

---

### Issue: "Execution takes too long"
**Symptom:** FactItems or FactSales generation exceeds 5 minutes

**Fix:**
- This is normal for first-time execution (creating ~36K items)
- Ensure SQL Server has adequate memory (recommend 4GB+)
- Check CPU usage - script is compute-intensive
- If > 10 minutes, check for missing indexes

---

### Issue: "Constraint violation"
**Error:** `CK_FactItems_SoldLogic` or similar

**Fix:**
1. Check if you ran scripts in order (dependencies matter!)
2. Verify dimension tables populated first
3. Re-run the failing script (they're idempotent with cleanup sections)

---

### Issue: "Different row counts than expected"
**Example:** FactBells shows 95 rows instead of ~130

**Explanation:**
- Row counts vary due to randomization (this is intentional!)
- Expected ranges:
  - FactLoans: 8 (exact)
  - FactBells: 120-140 ✓
  - FactItems: 35,000-38,000 ✓
  - FactSales: 20,000-24,000 ✓

**Only worry if:**
- FactLoans ≠ 8
- FactBells < 100 or > 150
- FactItems < 30,000
- Verification shows constraint violations

---

## Verification Checklist

After setup completes, run these checks:

### 1. Table Row Counts
```sql
SELECT 
    'DimCategories' AS TableName, COUNT(*) AS RowCount FROM dbo.DimCategories
UNION ALL SELECT 'DimSubcategories', COUNT(*) FROM dbo.DimSubcategories
UNION ALL SELECT 'DimBellSizes', COUNT(*) FROM dbo.DimBellSizes
UNION ALL SELECT 'DimItemGrades', COUNT(*) FROM dbo.DimItemGrades
UNION ALL SELECT 'DimDate', COUNT(*) FROM dbo.DimDate
UNION ALL SELECT 'FactLoans', COUNT(*) FROM dbo.FactLoans
UNION ALL SELECT 'FactLoanRepayments', COUNT(*) FROM dbo.FactLoanRepayments
UNION ALL SELECT 'FactBells', COUNT(*) FROM dbo.FactBells
UNION ALL SELECT 'FactItems', COUNT(*) FROM dbo.FactItems
UNION ALL SELECT 'FactSales', COUNT(*) FROM dbo.FactSales
UNION ALL SELECT 'FactExpenses', COUNT(*) FROM dbo.FactExpenses
UNION ALL SELECT 'FactCashMovements', COUNT(*) FROM dbo.FactCashMovements
ORDER BY TableName;
```

**Expected ranges:**
| Table | Expected Count |
|-------|----------------|
| DimCategories | 5 |
| DimSubcategories | 47 |
| DimBellSizes | 3 |
| DimItemGrades | 2 |
| DimDate | 366 |
| FactLoans | 8 |
| FactLoanRepayments | 60-80 |
| FactBells | 120-140 |
| FactItems | 35,000-38,000 |
| FactSales | 20,000-24,000 |
| FactExpenses | 180-220 |
| FactCashMovements | 1,100-1,400 |

### 2. Constraint Violations (Should be 0)
```sql
-- Check for any constraint violations
EXEC sp_MSforeachtable 'DBCC CHECKCONSTRAINTS(''?'') WITH ALL_CONSTRAINTS';
```

### 3. Referential Integrity
```sql
-- Verify all FKs are satisfied
SELECT 
    OBJECT_NAME(parent_object_id) AS ChildTable,
    OBJECT_NAME(referenced_object_id) AS ParentTable,
    name AS ForeignKey
FROM sys.foreign_keys
WHERE is_disabled = 0;
```

All foreign keys should be enabled (is_disabled = 0).

---

## Sample Queries

### Revenue by Month
```sql
SELECT 
    d.MonthName,
    FORMAT(SUM(fs.TotalAmount), 'C', 'en-NG') AS Revenue,
    COUNT(*) AS Transactions
FROM dbo.FactSales fs
JOIN dbo.DimDate d ON fs.SaleDateKey = d.DateKey
GROUP BY d.Month, d.MonthName
ORDER BY d.Month;
```

### Inventory Summary
```sql
SELECT 
    c.CategoryName,
    COUNT(*) AS TotalItems,
    SUM(CASE WHEN fi.IsSold = 1 THEN 1 ELSE 0 END) AS SoldItems,
    CAST(
        SUM(CASE WHEN fi.IsSold = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS SellThroughPct
FROM dbo.FactItems fi
JOIN dbo.DimCategories c ON fi.CategoryID = c.CategoryID
GROUP BY c.CategoryName
ORDER BY COUNT(*) DESC;
```

More examples in: `database/verification/sample_queries.sql`

---

## Next Steps

Once setup is complete:

1. ✅ Explore the data using sample queries
2. ✅ Review [ARCHITECTURE.md](docs/ARCHITECTURE.md) to understand design decisions
3. ✅ Read [AI_COLLABORATION.md](docs/AI_COLLABORATION.md) to see the development process
4. ✅ Start building Power BI dashboards (Phase 3)

---

## Need Help?

- 📖 Check [docs/](docs/) folder for detailed documentation
- 🐛 Open an issue on GitHub
- 💬 Review [AI_COLLABORATION.md](docs/AI_COLLABORATION.md) for troubleshooting patterns

---

**Project:** Amazing Grace Store Data Warehouse  
**Author:** Ibeh Chidera Elijah  
**GitHub:** [@Elijjjaaaahhhhh](https://github.com/Elijjjaaaahhhhh)
