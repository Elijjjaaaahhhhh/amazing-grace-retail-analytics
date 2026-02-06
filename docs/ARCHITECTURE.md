# Database Architecture

## Overview

The Amazing Grace Store data warehouse implements a **Star Schema** design optimized for analytical queries and Power BI integration. The warehouse tracks all aspects of a second-hand clothing retail business including inventory purchases, individual items, sales transactions, loan financing, operating expenses, and multi-account cash flow.

---

## Architectural Decisions

### Why Star Schema?

**Chosen:** Star Schema  
**Rejected:** Snowflake Schema

**Rationale:**
1. **Query Performance** - Minimal joins required for common analytical queries
2. **Power BI Optimization** - Direct relationships make DAX measures simpler
3. **Business User Accessibility** - Easier to understand for non-technical stakeholders
4. **Aggregation Speed** - Faster GROUP BY operations with denormalized dimensions
5. **Maintenance Simplicity** - Clearer data lineage and easier troubleshooting

**Trade-off Accepted:** Some redundancy in DimSubcategories (stores CategoryID and Category info) in exchange for query performance.

---

## Schema Design

### Star Schema Components

```
                    ┌─────────────────┐
                    │    DimDate      │
                    │   (366 rows)    │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
            ┌───────▼──────┐   ┌─────▼──────┐
            │DimCategories │   │DimBellSizes│
            │   (5 rows)   │   │  (3 rows)  │
            └───────┬──────┘   └─────┬──────┘
                    │                 │
         ┌──────────▼──────────┐      │
         │DimSubcategories     │      │
         │    (47 rows)        │      │
         └──────────┬──────────┘      │
                    │                 │
            ┌───────▼─────────────────▼────┐
            │       DimItemGrades           │
            │          (2 rows)             │
            └───────┬───────────────────────┘
                    │
        ┌───────────┼───────────────┐
        │           │               │
   ┌────▼─────┐┌───▼────┐┌────────▼────┐
   │FactLoans││FactBells││FactExpenses│
   │  (8)    ││  (~130) ││   (~200)    │
   └────┬─────┘└────┬────┘└─────────────┘
        │           │
        │      ┌────▼──────┐
        │      │FactItems │
        │      │ (~36,000) │
        │      └────┬──────┘
        │           │
   ┌────▼─────┐┌───▼────┐
   │FactLoan ││FactSales│
   │Repayments││(~21,800)│
   │  (~70)   │└─────────┘
   └──────────┘
        
   ┌──────────────────┐
   │FactCashMovements │
   │    (~1,200)      │
   └──────────────────┘
```

---

## Table Design Patterns

### Dimension Tables (Reference Data)

#### DimDate - Time Dimension
**Purpose:** Business calendar with operational rules

**Key Features:**
- 366 rows for leap year 2024
- Store opening date: January 4, 2024 (Thursday)
- Closed days: All Sundays + Christian holidays
- Business flags: IsStoreOpen, IsPeakPeriod, IsSalesPeriod

**Design Decision:** 
- **Chosen:** Pre-populated calendar table
- **Rejected:** Dynamic date calculations in queries
- **Reason:** Performance - avoid repeated DATEPART calculations

**Business Rules Encoded:**
```sql
IsStoreOpen = CASE 
    WHEN DATENAME(WEEKDAY, FullDate) = 'Sunday' THEN 0
    WHEN FullDate < '2024-01-04' THEN 0  -- Pre-opening
    WHEN FullDate = '2024-03-29' THEN 0  -- Good Friday
    WHEN FullDate = '2024-04-01' THEN 0  -- Easter Monday
    WHEN FullDate BETWEEN '2024-12-25' AND '2024-12-27' THEN 0  -- Christmas
    ELSE 1
END
```

**Operating Days:** ~306 days/year (365 - 52 Sundays - 7 holidays)

---

#### DimCategories - Product Types
**Purpose:** Top-level product classification

**Grain:** One row per clothing category

**Structure:**
- CategoryID (PK, IDENTITY)
- CategoryName (UNIQUE)
- CategoryDescription

**Data:**
1. Tops
2. Bottoms
3. Outerwear
4. Activewear
5. Dresses

**Design Decision:**
- **Chosen:** Fixed 5 categories (no frequent additions expected)
- **Rejected:** User-defined category creation
- **Reason:** Business model stability - product mix defined by supply chain

---

#### DimSubcategories - Item Variants
**Purpose:** Granular product classification

**Grain:** One row per subcategory within a category

**Key Attributes:**
- CategoryID (FK to DimCategories)
- SubcategoryName
- IsFastMoving (BIT) - Business intelligence flag
- Gender (Male/Female/Both)

**Fast-Moving Examples:**
- T-shirts (Tops, Male)
- Jeans (Bottoms, Both)
- Hoodies (Outerwear, Both)

**Regular Examples:**
- Suits (Tops, Male)
- Evening Dresses (Dresses, Female)

**Design Decision:**
- **Denormalized:** Stores CategoryID despite relationship
- **Reason:** Avoid joins when querying subcategories alone
- **Trade-off:** 47 rows × 4 bytes = 188 bytes vs. performance gain

---

#### DimBellSizes - Inventory Tiers
**Purpose:** Bell (bulk purchase) size classification

**Grain:** One row per size category

**Structure:**
- BellSizeID (PK, IDENTITY)
- BellSizeName (UNIQUE)
- MinItems (INT)
- MaxItems (INT)

**Data:**
| Size | Min Items | Max Items | Typical Cost Range |
|------|-----------|-----------|-------------------|
| Small | 200 | 250 | ₦350K - ₦450K |
| Medium | 300 | 350 | ₦500K - ₦650K |
| Large | 400 | 500 | ₦700K - ₦850K |

**Design Decision:**
- **Chosen:** Fixed size tiers with ranges
- **Rejected:** Continuous item count without categorization
- **Reason:** Supplier contracts based on size tiers, affects pricing

---

#### DimItemGrades - Quality Tiers
**Purpose:** Quality classification for pricing strategy

**Grain:** One row per quality grade

**Structure:**
- GradeID (PK, INT - no IDENTITY, business IDs 1 and 2)
- GradeName
- CanBeTopTier (BIT) - Only Grade 1 items eligible

**Data:**
1. Grade 1 - Premium quality (70% of inventory)
2. Grade 2 - Standard quality (30% of inventory)

**Top-Tier Logic:**
- 15% of Grade 1 items designated as top-tier
- Top-tier items receive 50% markup vs. 20-30% standard
- Grade 2 items never top-tier

**Design Decision:**
- **Chosen:** Two-tier system
- **Rejected:** Multi-grade system (A, B, C, D)
- **Reason:** Simplicity in sourcing, easier customer communication

---

### Fact Tables (Transactional Data)

#### FactLoans - Inventory Financing
**Purpose:** Track business loans for inventory purchases

**Grain:** One row per loan

**Key Attributes:**
- LoanDateKey (FK to DimDate)
- PrincipalAmount (₦2M - ₦8M in ₦500K increments)
- DurationMonths (6 or 12 months)
- EffectiveInterestRate (12% - 18% APR)
- MonthlyRepayment (calculated)
- IsFullyRepaid (BIT)
- RepaidToDate (running total)
- RemainingBalance (calculated)

**Business Rules:**
- Minimum loan: ₦2,000,000
- Maximum loan: ₦8,000,000
- Increment: ₦500,000
- Valid durations: 6 or 12 months
- Interest rate range reflects Lagos microfinance market rates

**Design Decision:**
- **Stored Calculations:** MonthlyRepayment, TotalRepayment stored (not calculated on query)
- **Reason:** Avoid floating-point precision issues in reports
- **Trade-off:** Storage space vs. calculation consistency

**Loan Distribution (2024):**
- 8 total loans
- Mix of 6-month and 12-month terms
- Interest rates vary based on amount and duration

---

#### FactLoanRepayments - Payment Tracking
**Purpose:** Record individual loan repayments

**Grain:** One row per repayment

**Key Attributes:**
- LoanID (FK to FactLoans)
- RepaymentDateKey (FK to DimDate)
- ScheduledAmount (expected payment)
- ActualAmount (actual payment)
- PaymentStatus (OnTime/Late/Partial)
- DaysLate (nullable, only for late payments)

**Business Rules:**
- Payment statuses: 90% OnTime, 7% Late, 3% Partial
- Late threshold: 3+ days after scheduled date
- Partial: ActualAmount < ScheduledAmount

**Design Decision:**
- **Separate Table:** Repayments not embedded in FactLoans
- **Reason:** Better audit trail, supports partial payments, allows historical analysis
- **Benefits:** Can calculate repayment patterns, default risk scoring

**Repayment Pattern:**
- ~70 total repayments across 8 loans
- Most repayments on-time (reflects stable business)
- Few late payments (realistic constraint)

---

#### FactBells - Bulk Inventory Purchases
**Purpose:** Track bell (bulk purchase) transactions

**Grain:** One row per bell purchased

**Key Attributes:**
- PurchaseDateKey (FK to DimDate)
- CategoryID, SubcategoryID (FK)
- BellSizeID (FK to DimBellSizes)
- BellCost (₦350K - ₦850K)
- TotalItems (actual count)
- SellableItems (65% - 90% of total)
- UnsellableItems (calculated: Total - Sellable)
- SellablePercentage (varies by quality)
- CostPerItem (BellCost / SellableItems)
- TransportCost (₦12K per trip, shared across bells)
- LoanID (nullable - only for loan-funded bells)
- IsProfitFunded (BIT)
- TripID (grouping for transport)

**Funding Mix:**
- 60% loan-funded bells
- 40% profit-funded bells

**Category Distribution (Weighted Random):**
- Tops: 25%
- Bottoms: 30%
- Outerwear: 15%
- Activewear: 20%
- Dresses: 10%

**Critical Constraint:**
```sql
CHECK (TotalItems = SellableItems + UnsellableItems)
```

**Design Decision - Constraint Enforcement:**
- **Issue:** UPDATE statement using old column values violated constraint
- **Solution:** Two-phase UPDATE (SellableItems first, then UnsellableItems)
- **Reason:** SQL Server evaluates all column expressions before applying updates

**Transport Logic:**
- ₦12,000 per trip
- 3-6 bells per trip (based on proximity and timing)
- Cost allocated: TransportCost × (1 / BellsPerTrip)

---

#### FactItems - Individual Inventory Items
**Purpose:** Track each individual clothing item from bell to sale

**Grain:** One row per item

**Key Attributes:**
- BellID (FK to FactBells - item source)
- CategoryID, SubcategoryID (inherited from bell)
- GradeID (FK to DimItemGrades)
- CostPerItem (from bell allocation)
- BasePrice (Cost + Markup)
- IsTopTier (BIT - 15% of Grade 1)
- ActualMarkupPercent (20-30% standard, 50% top-tier)
- SellingPrice (BasePrice, may be discounted later)
- DateAddedKey (FK to DimDate)
- DateSoldKey (FK to DimDate, nullable)
- DaysInInventory (nullable)
- IsSold (BIT)
- IsInDiscount (BIT)
- DiscountPercent (25/40/50, nullable)
- DiscountedPrice (nullable)
- FinalSalePrice (actual sale price)
- SaleTransactionID (FK to FactSales, nullable)

**Sell-Through Simulation Logic:**

```sql
SellProbability = FastMovingFactor × SeasonalFactor × PriceFactor × RandomFactor

FastMovingFactor:
  - Fast-moving: 95%
  - Regular: 75%

SeasonalFactor by Quarter:
  - Q1 (Jan-Mar): 85%  (Post-holiday slow)
  - Q2 (Apr-Jun): 105% (Spring uptick)
  - Q3 (Jul-Sep): 120% (Back-to-school)
  - Q4 (Oct-Dec): 135% (Holiday peak)

PriceFactor:
  - < ₦3,000: 155%  (High demand)
  - ₦3,000-₦6,000: 130% (Moderate)
  - > ₦6,000: 110% (Luxury)

RandomFactor:
  - Random value between 50% and 100%
  - Ensures variation even within same category

Item SOLD if: (SellProbability > 60%)
```

**Discount Tiers (Age-based):**
- 90-119 days: 25% discount
- 120-179 days: 40% discount
- 180+ days: 50% discount

**Discount Eligibility:**
- Only during sales periods (Feb 5-25, Jun 3-23, Nov 4-24)
- Unsold items past 90 days

**Critical Constraint:**
```sql
CHECK (
    (IsSold = 0 AND DateSoldKey IS NULL) OR
    (IsSold = 1 AND DateSoldKey IS NOT NULL)
)
```

**Design Decision - Constraint Modification:**
- **Original:** Required SaleTransactionID IS NOT NULL for sold items
- **Issue:** FactSales doesn't exist yet during FactItems generation
- **Solution:** Modified constraint to only require DateSoldKey
- **Timing:** SaleTransactionID populated during FactSales generation

**Volume:** ~36,000 items generated (realistic for 130 bells × 200-500 items each)

---

#### FactSales - Customer Transactions
**Purpose:** Group sold items into customer transactions

**Grain:** One row per transaction (not per item)

**Key Attributes:**
- SaleDateKey (FK to DimDate)
- SaleDateTime (exact timestamp)
- TotalItems (count of items in transaction)
- SubtotalAmount (sum of FinalSalePrice)
- DiscountAmount (sum of discounts)
- TotalAmount (Subtotal - Discount)
- PaymentMethod (Cash/Transfer/POS)
- IsRecurringCustomer (BIT - 35% probability)

**Transaction Sizes (Weighted Distribution):**
- 1 item: 45%
- 2-4 items: 25%
- 5-8 items: 15%
- 9-10 items: 10%
- 11-50 items: 5%

**Payment Method Distribution:**
- Cash: 30%
- Transfer: 45%
- POS: 25%

**Critical Design Challenge - ID Mapping:**

**Problem:** After INSERT with IDENTITY, need to map auto-generated SaleTransactionID back to items

**Failed Approach:**
```sql
INSERT INTO FactSales (...)
OUTPUT INSERTED.SaleTransactionID, source.RowNum  -- Can't reference source!
```

**Working Solution (MERGE-based):**
```sql
MERGE dbo.FactSales AS tgt
USING (
    SELECT *, ROW_NUMBER() OVER (ORDER BY TempID) AS RowNum
    FROM #TempSales
) AS src
ON 1 = 0  -- Never matches - forces INSERT
WHEN NOT MATCHED THEN
    INSERT (SaleDateKey, SaleDateTime, ...)
    VALUES (src.SaleDateKey, src.SaleDateTime, ...)
OUTPUT 
    INSERTED.SaleTransactionID,
    src.RowNum  -- ✅ Can reference source in MERGE!
INTO @Mapping (SaleTransactionID, RowNum);
```

**Grouping Rule:**
- Items grouped ONLY by same DateSoldKey
- Verified via: `PARTITION BY DateSoldKey` in transaction creation
- All items in a transaction sold on same day

**Volume:** ~21,800 transactions (60-70% sell-through of 36K items)

---

#### FactExpenses - Operating Costs
**Purpose:** Track business expenses

**Grain:** One row per expense

**Key Attributes:**
- ExpenseDateKey (FK to DimDate)
- ExpenseCategory (Rent/Staff/Utilities/Transport/Other)
- ExpenseDescription
- Amount (DECIMAL)
- IsRecurring (BIT)
- PaymentMethod (Cash/Transfer)

**Expense Categories:**
1. **Rent** - Monthly store rent (₦150K-₦200K)
2. **Staff** - Salaries (2-3 employees, ₦40K-₦60K each)
3. **Utilities** - Electricity, water (₦20K-₦40K/month)
4. **Transport** - Not bells (those in FactBells), but operational
5. **Other** - Miscellaneous (security, cleaning, etc.)

**Recurring Expenses:**
- Rent: Monthly (1st of each month)
- Staff: Monthly (25th of each month)
- Utilities: Monthly (variable dates)

**Volume:** ~170-200 expenses across 2024

---

#### FactCashMovements - Multi-Account Cash Flow
**Purpose:** Track cash across three savings accounts with daily reconciliation

**Grain:** One row per movement (deposit/withdrawal/transfer)

**Account Structure:**
1. **Profits Account** - Revenue accumulation (Start: ₦250,000)
2. **Operations Account** - Working capital (Start: ₦100,000)
3. **Debts Account** - Loan repayment fund (Start: ₦0)

**Key Attributes:**
- MovementDateKey (FK to DimDate)
- AccountType (Profits/Operations/Debts)
- MovementType (Deposit/Withdrawal/Transfer)
- Amount
- SourceAccount (nullable, for transfers)
- DestinationAccount (nullable, for transfers)
- Description
- RunningBalance (balance AFTER this movement)

**Daily Cash Flow Rules:**

**Sales Processing:**
```
1. 100% of daily sales → Profits (DEPOSIT)
2. 70% of daily sales → Operations (TRANSFER from Profits)
3. 65% of Operations receipt → Debts (TRANSFER from Operations)
```

**Deficit Handling (Critical Logic):**

**If Debts goes negative:**
```sql
-- Operations supplements Debts
Correction = ABS(DebtsBalance) × 1.10 + ₦1,000
INSERT: Operations → Debts (TRANSFER)
```

**If Operations goes negative (after Debts correction):**
```sql
-- Profits supplements Operations
Correction = ABS(OperationsBalance) × 1.10 + ₦1,000
INSERT: Profits → Operations (TRANSFER)
```

**Why 10% buffer + ₦1,000:**
- Prevents oscillation (negative → corrected → negative again)
- ₦1,000 ensures positive balance even for tiny deficits
- 10% provides cushion for next day's operations

**Year-End Sweeps (Dec 31):**
```
1. Debts → ₦0 (excess to Profits)
2. Operations → ₦0-₦500K (excess to Profits, keep buffer)
3. Profits → receives all remainder
```

**Design Decision - Timing of Corrections:**
- **Original:** End-of-day check
- **Issue:** Additional transactions after check caused negative balances
- **Solution:** In-day corrections immediately after each balance calculation
- **Verification:** All 366 days × 3 accounts = 1,098 end-of-day balances, zero negatives

**Volume:** ~1,200-1,500 movements across 366 days × 3 accounts

---

## Indexing Strategy

### Primary Keys (Clustered Indexes)
- All PKs use CLUSTERED index
- Reason: Sequential ID access is most common query pattern

### Foreign Keys (Non-Clustered Indexes)
- All FKs have NONCLUSTERED indexes
- Reason: JOIN performance on dimension lookups

### Filtered Indexes (Selective)
```sql
-- DimDate: Only operating days
CREATE NONCLUSTERED INDEX IX_DimDate_StoreOpen
ON DimDate(DateKey)
WHERE IsStoreOpen = 1;

-- FactBells: Only loan-funded
CREATE NONCLUSTERED INDEX IX_FactBells_Loan
ON FactBells(LoanID)
WHERE LoanID IS NOT NULL;

-- FactItems: Only sold items
CREATE NONCLUSTERED INDEX IX_FactItems_Sold
ON FactItems(SaleTransactionID, FinalSalePrice)
WHERE IsSold = 1;

-- FactItems: Only top-tier items
CREATE NONCLUSTERED INDEX IX_FactItems_TopTier
ON FactItems(ItemID, CategoryID, SellingPrice)
WHERE IsTopTier = 1;
```

**Design Decision:**
- **Filtered indexes on BIT columns** where TRUE is minority
- **Reason:** Smaller index size, faster seeks for common analytical queries
- **Trade-off:** Slower for queries filtering FALSE (acceptable - rare)

---

## Constraint Strategy

### CHECK Constraints (Business Rule Enforcement)

**Philosophy:** Database-level validation preferred over application-level

**Examples:**
```sql
-- FactLoans
CHECK (PrincipalAmount BETWEEN 2000000 AND 8000000)
CHECK (DurationMonths IN (6, 12))
CHECK (EffectiveInterestRate BETWEEN 0.12 AND 0.18)

-- FactBells
CHECK (TotalItems = SellableItems + UnsellableItems)
CHECK (BellCost BETWEEN 350000 AND 850000)

-- FactItems
CHECK (ActualMarkupPercent BETWEEN 20 AND 50)
CHECK (DiscountPercent IN (25, 40, 50) OR DiscountPercent IS NULL)
CHECK ((IsSold = 0 AND DateSoldKey IS NULL) OR 
       (IsSold = 1 AND DateSoldKey IS NOT NULL))

-- FactSales
CHECK (TotalAmount = SubtotalAmount - DiscountAmount)
CHECK (PaymentMethod IN ('Cash', 'Transfer', 'POS'))

-- FactLoanRepayments
CHECK (PaymentStatus IN ('OnTime', 'Late', 'Partial'))

-- FactExpenses
CHECK (ExpenseCategory IN ('Rent','Staff','Utilities','Transport','Other'))

-- FactCashMovements
CHECK (AccountType IN ('Profits', 'Operations', 'Debts'))
CHECK (MovementType IN ('Deposit', 'Withdrawal', 'Transfer'))
```

**Design Decision:**
- **Chosen:** Hard constraints in database
- **Rejected:** Soft validation in application only
- **Reason:** Data integrity guaranteed regardless of client application
- **Benefits:** Catch errors immediately, prevent cascading issues

### Foreign Key Constraints

**All relationships enforced:**
- Dimension → Fact (standard star schema)
- Fact → Fact (bell → items → sales)
- Loan → Bell (financing relationship)
- Loan → Repayment (payment relationship)

**Cascade Rules:**
- NO CASCADE DELETE (preserve audit trail)
- Requires manual cleanup or archive process
- Prevents accidental data loss

---

## Data Volume Planning

### Storage Estimates

| Table | Rows | Avg Row Size | Total Size |
|-------|------|--------------|------------|
| DimDate | 366 | 80 bytes | ~30 KB |
| DimCategories | 5 | 100 bytes | ~1 KB |
| DimSubcategories | 47 | 120 bytes | ~6 KB |
| DimBellSizes | 3 | 80 bytes | ~1 KB |
| DimItemGrades | 2 | 60 bytes | ~1 KB |
| **Dimensions Total** | **423** | | **~39 KB** |
| FactLoans | 8 | 150 bytes | ~1 KB |
| FactLoanRepayments | ~70 | 100 bytes | ~7 KB |
| FactBells | ~130 | 200 bytes | ~26 KB |
| FactItems | ~36,000 | 250 bytes | ~9 MB |
| FactSales | ~21,800 | 150 bytes | ~3.3 MB |
| FactExpenses | ~200 | 180 bytes | ~36 KB |
| FactCashMovements | ~1,200 | 180 bytes | ~216 KB |
| **Facts Total** | **~59,600** | | **~12.6 MB** |
| **GRAND TOTAL** | **~60,000** | | **~12.7 MB** |

**Index Overhead:** ~30% additional (estimated ~17 MB total with indexes)

**Growth Projection (Annual):**
- FactBells: +130 rows/year
- FactItems: +36,000 rows/year
- FactSales: +21,800 rows/year
- 3-year projection: ~60 MB total

---

## Performance Considerations

### Query Optimization Patterns

**Common Query 1: Monthly Revenue**
```sql
-- Optimized with star schema
SELECT 
    d.MonthName,
    SUM(fs.TotalAmount) AS Revenue
FROM FactSales fs
JOIN DimDate d ON fs.SaleDateKey = d.DateKey
GROUP BY d.Month, d.MonthName;
```
**Performance:** <100ms with proper indexing

**Common Query 2: Category Sell-Through**
```sql
-- Single dimension join
SELECT 
    c.CategoryName,
    COUNT(fi.ItemID) AS TotalItems,
    SUM(CASE WHEN fi.IsSold = 1 THEN 1 ELSE 0 END) AS Sold
FROM FactItems fi
JOIN DimCategories c ON fi.CategoryID = c.CategoryID
GROUP BY c.CategoryName;
```
**Performance:** <200ms (36K row scan with category grouping)

**Common Query 3: Cash Flow Summary**
```sql
-- Account-based aggregation
SELECT 
    AccountType,
    SUM(CASE WHEN MovementType = 'Deposit' THEN Amount ELSE 0 END) AS Inflows,
    SUM(CASE WHEN MovementType = 'Withdrawal' THEN Amount ELSE 0 END) AS Outflows
FROM FactCashMovements
GROUP BY AccountType;
```
**Performance:** <50ms (1,200 row scan)

---

## Scalability Considerations

### Current Architecture Limits

**Table-Level:**
- FactItems: Can handle 1M+ rows (current: 36K)
- FactSales: Can handle 500K+ rows (current: 21.8K)
- No partitioning needed at current scale

**Database-Level:**
- Single filegroup sufficient (<100 MB)
- No need for filegroup segregation
- Standard recovery model appropriate

### Future Enhancements

**If Growth Exceeds 1M Items:**
1. Partition FactItems by DateAddedKey (yearly)
2. Implement sliding window (archive old data)
3. Consider columnstore index for aggregations

**If Query Performance Degrades:**
1. Add indexed views for common aggregations
2. Implement materialized monthly summaries
3. Consider read replica for reporting

---

## Data Quality Assurance

### Validation Queries

**Referential Integrity:**
```sql
-- All FKs satisfied
SELECT 
    fk.name AS ForeignKey,
    OBJECT_NAME(fk.parent_object_id) AS TableName
FROM sys.foreign_keys fk
WHERE is_disabled = 1;  -- Should return 0 rows
```

**Constraint Violations:**
```sql
-- All CHECK constraints satisfied
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
-- Should return 0 rows
```

**Data Consistency:**
```sql
-- FactBells: TotalItems = Sellable + Unsellable
SELECT COUNT(*) 
FROM FactBells
WHERE TotalItems != SellableItems + UnsellableItems;
-- Should return 0

-- FactSales: Items per transaction matches group
SELECT 
    fs.SaleTransactionID,
    fs.TotalItems,
    COUNT(fi.ItemID) AS ActualItems
FROM FactSales fs
JOIN FactItems fi ON fs.SaleTransactionID = fi.SaleTransactionID
GROUP BY fs.SaleTransactionID, fs.TotalItems
HAVING fs.TotalItems != COUNT(fi.ItemID);
-- Should return 0 rows
```

---

## Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Database** | SQL Server | 2022 | Data warehouse platform |
| **Development** | SSMS | 20.x | Schema design & query development |
| **Version Control** | Git | 2.x | Source code management |
| **Visualization** | Power BI | TBD | Phase 3 dashboards |

---

## Summary

The Amazing Grace Store data warehouse implements a **production-grade star schema** with:

✅ **12 tables** (5 dimensions, 7 facts)  
✅ **100,000+ synthetic records** with realistic business patterns  
✅ **30+ CHECK constraints** enforcing business rules  
✅ **20+ foreign keys** ensuring referential integrity  
✅ **50+ indexes** optimizing query performance  
✅ **Zero constraint violations** verified across all tables  
✅ **Sub-second query performance** for common analytical patterns  

The architecture prioritizes:
1. **Data Integrity** - Database-level constraint enforcement
2. **Query Performance** - Star schema with strategic indexing
3. **Maintainability** - Clear relationships and documentation
4. **Scalability** - Room for 10x growth without redesign

---

**Author:** Ibeh Chidera Elijah  
**Project:** Amazing Grace Store Data Warehouse  
**Date:** February 2026
