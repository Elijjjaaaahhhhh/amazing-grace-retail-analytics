# Project Phases

## Overview

The Amazing Grace Store Data Warehouse project is designed in three distinct phases, demonstrating a structured approach to building a complete data analytics solution. Each phase builds upon the previous one, showcasing different skill sets and technical capabilities.

---

## Phase 1: Database Schema Design ✅ COMPLETE

**Objective:** Design and implement a production-grade star schema data warehouse

**Duration:** ~4 hours (with AI assistance)

**Deliverables:**
- Complete database design (12 tables)
- 5 dimension tables
- 7 fact tables
- 20+ foreign key relationships
- 30+ CHECK constraints
- 50+ indexes (clustered, non-clustered, filtered)
- Complete DDL scripts

---

### Dimension Tables (5)

#### 1. DimDate (366 rows)
**Purpose:** Business calendar with operational rules

**Key Features:**
- Full year 2024 (leap year)
- Store opening: January 4, 2024
- Operating schedule: Closed Sundays + holidays
- Business flags: IsStoreOpen, IsPeakPeriod, IsSalesPeriod
- Fiscal calendar support

**Skills Demonstrated:**
- Recursive CTE for date generation
- Complex CASE statements for business rules
- Calendar dimension best practices

---

#### 2. DimCategories (5 rows)
**Purpose:** Top-level product classification

**Data:**
1. Tops
2. Bottoms
3. Outerwear
4. Activewear
5. Dresses

**Skills Demonstrated:**
- Simple dimension design
- UNIQUE constraints
- Master data management

---

#### 3. DimSubcategories (47 rows)
**Purpose:** Granular product classification

**Attributes:**
- CategoryID (FK to DimCategories)
- SubcategoryName
- IsFastMoving flag
- Gender classification

**Skills Demonstrated:**
- Hierarchical dimension design
- Business intelligence flags
- Composite UNIQUE constraints

---

#### 4. DimBellSizes (3 rows)
**Purpose:** Inventory tier classification

**Data:**
- Small (200-250 items, ₦350K-₦450K)
- Medium (300-350 items, ₦500K-₦650K)
- Large (400-500 items, ₦700K-₦850K)

**Skills Demonstrated:**
- Range-based classification
- CHECK constraints for data validation

---

#### 5. DimItemGrades (2 rows)
**Purpose:** Quality tier classification

**Data:**
1. Grade 1 (Premium, top-tier eligible)
2. Grade 2 (Standard, not top-tier eligible)

**Skills Demonstrated:**
- Binary classification design
- Business key constraints (fixed IDs)

---

### Fact Tables (7)

#### 1. FactLoans (8 loans)
**Purpose:** Inventory financing tracking

**Grain:** One row per loan

**Key Metrics:**
- Principal Amount (₦2M-₦8M)
- Duration (6 or 12 months)
- Interest Rate (12%-18%)
- Monthly Repayment
- Repayment Status

**Skills Demonstrated:**
- Financial calculations
- CHECK constraints for business rules
- Status tracking

---

#### 2. FactLoanRepayments (~70 repayments)
**Purpose:** Individual loan payment tracking

**Grain:** One row per repayment

**Key Metrics:**
- Scheduled vs Actual amounts
- Payment Status (OnTime/Late/Partial)
- Days Late tracking

**Skills Demonstrated:**
- Transactional fact table design
- Audit trail implementation
- Status classification

---

#### 3. FactBells (~130 bells)
**Purpose:** Bulk inventory purchase tracking

**Grain:** One row per bell

**Key Metrics:**
- Bell Cost
- Total/Sellable/Unsellable items
- Cost per item
- Funding source (Loan/Profit)
- Transport allocation

**Skills Demonstrated:**
- Complex calculated columns
- Constraint interdependencies
- Funding relationship modeling

---

#### 4. FactItems (~36,000 items)
**Purpose:** Individual item inventory tracking

**Grain:** One row per item

**Key Metrics:**
- Cost per item
- Pricing (base, selling, final sale)
- Grade and top-tier flags
- Discount calculations
- Sell status and dates
- Days in inventory

**Skills Demonstrated:**
- Large-scale fact table design
- Lifecycle tracking (added → sold)
- Conditional pricing logic
- Status flags management

---

#### 5. FactSales (~21,800 transactions)
**Purpose:** Customer transaction grouping

**Grain:** One row per transaction (not per item)

**Key Metrics:**
- Transaction totals
- Payment method
- Customer type (recurring/new)
- Item count per transaction

**Skills Demonstrated:**
- Transaction-level aggregation
- Relationship to line items (FactItems)
- Payment method tracking

---

#### 6. FactExpenses (~200 expenses)
**Purpose:** Operating expense tracking

**Grain:** One row per expense

**Key Metrics:**
- Expense category
- Amount
- Recurring flag
- Payment method

**Skills Demonstrated:**
- Operational fact table design
- Category classification
- Recurring pattern tracking

---

#### 7. FactCashMovements (~1,200 movements)
**Purpose:** Multi-account cash flow tracking

**Grain:** One row per movement

**Key Metrics:**
- Account balances (Profits, Operations, Debts)
- Movement types (Deposit, Withdrawal, Transfer)
- Running balances
- Daily reconciliation

**Skills Demonstrated:**
- Financial reconciliation logic
- Multi-account tracking
- Balance calculations
- Transfer relationship modeling

---

### Database Constraints

**Foreign Keys:** 20+
- All dimension relationships
- Bell → Items relationship
- Loan → Bell relationship
- Loan → Repayments relationship
- Sales → Items relationship

**CHECK Constraints:** 30+
- Loan parameters (amount, duration, rate)
- Bell composition (Total = Sellable + Unsellable)
- Item pricing (markup ranges, discount tiers)
- Sales totals (Total = Subtotal - Discount)
- Payment methods, statuses, categories

**UNIQUE Constraints:** 5+
- Dimension name fields
- Natural keys where applicable

---

### Indexing Strategy

**Clustered Indexes:** 12 (all PKs)

**Non-Clustered Indexes:** 20+ (all FKs)

**Filtered Indexes:** 4
- DimDate (IsStoreOpen = 1)
- FactBells (LoanID IS NOT NULL)
- FactItems (IsSold = 1)
- FactItems (IsTopTier = 1)

**Skills Demonstrated:**
- Query optimization strategy
- Selective indexing
- Understanding index overhead vs benefit

---

### Design Decisions & Trade-offs

**Star Schema vs Snowflake:**
- ✅ Chose Star Schema
- Rationale: Query performance, Power BI optimization, simplicity

**Denormalization:**
- DimSubcategories stores CategoryID (could normalize)
- Trade-off: Small redundancy (188 bytes) vs query performance

**Constraint Enforcement:**
- ✅ Database-level constraints
- ❌ Application-level only
- Rationale: Data integrity guarantee regardless of client

**Calculated vs Stored:**
- ✅ Stored: MonthlyRepayment, TotalRepayment, RunningBalance
- ❌ Calculated on query
- Rationale: Avoid floating-point precision issues, consistency

---

## Phase 2: Synthetic Data Generation ✅ COMPLETE

**Objective:** Generate realistic synthetic data matching all business rules

**Duration:** ~12 hours (with AI assistance)

**Deliverables:**
- ~100,000+ records across 12 tables
- Complete referential integrity
- Zero constraint violations
- Realistic business patterns
- Weighted random distributions
- Data generation scripts for all tables

---

### Data Generation Approach

#### Dimensions: Static Reference Data

**Method:** INSERT with hardcoded values

**Tables:**
- DimCategories (5 rows) - Manual insert
- DimSubcategories (47 rows) - Manual insert with category relationships
- DimBellSizes (3 rows) - Manual insert with ranges
- DimItemGrades (2 rows) - Manual insert with flags
- DimDate (366 rows) - Recursive CTE generation

**Skills Demonstrated:**
- Reference data management
- Hierarchical data insertion
- Calendar generation algorithms

---

#### Facts: Synthetic Transactional Data

**Method:** Procedural generation with weighted distributions

---

##### FactLoans (8 loans)

**Generation Logic:**
- Loan dates: Spread across 2024
- Principal: ₦2M-₦8M in ₦500K increments
- Duration: Random 6 or 12 months
- Interest: Random 12%-18%
- Calculate monthly repayment and total

**Skills Demonstrated:**
- Financial calculation logic
- Random value generation with constraints
- Date distribution across year

---

##### FactLoanRepayments (~70 repayments)

**Generation Logic:**
- For each loan, generate monthly repayments
- 90% OnTime, 7% Late, 3% Partial
- Calculate scheduled dates (monthly intervals)
- Vary actual amount for Partial payments
- Calculate days late for Late payments

**Skills Demonstrated:**
- Date arithmetic
- Weighted random status selection
- Realistic payment patterns

---

##### FactBells (~130 bells)

**Generation Logic:**

**Weighted Category Distribution:**
```sql
CASE (ABS(CHECKSUM(NEWID())) % 100)
    WHEN < 25 THEN Tops (25%)
    WHEN < 55 THEN Bottoms (30%)
    WHEN < 70 THEN Outerwear (15%)
    WHEN < 90 THEN Activewear (20%)
    ELSE Dresses (10%)
END
```

**Subcategory Selection:**
- Filter subcategories by category
- Random selection within category
- Respect fast-moving distribution

**Bell Size Distribution:**
- Small: 30%
- Medium: 40%
- Large: 30%

**Item Count & Cost:**
- Random within size min/max range
- Cost varies by size tier
- Sellable percentage: 65%-90%

**Critical Constraint Handling:**
```sql
-- Phase 1: Calculate SellableItems
UPDATE SET SellableItems = CAST(TotalItems * SellablePercentage AS INT)

-- Phase 2: Calculate UnsellableItems (uses NEW SellableItems value)
UPDATE SET UnsellableItems = TotalItems - SellableItems
```

**Funding Assignment:**
- 60% loan-funded (assign LoanID)
- 40% profit-funded (LoanID = NULL)
- 8-12 bells per loan
- Purchased within 60 days of loan date

**Skills Demonstrated:**
- Weighted random distributions
- Complex constraint handling
- Two-phase UPDATE pattern
- Funding relationship logic

---

##### FactItems (~36,000 items)

**Generation Logic:**

**Item Creation:**
- For each bell, create SellableItems count of items
- Inherit CategoryID, SubcategoryID from bell
- Assign CostPerItem from bell

**Grade Distribution:**
- 70% Grade 1
- 30% Grade 2

**Top-Tier Selection:**
- 15% of Grade 1 items
- Grade 2 never top-tier

**Pricing:**
```
BasePrice = CostPerItem × (1 + MarkupPercent)
  - Standard: 20%-30%
  - Top-tier: 50%

SellingPrice = BasePrice (initial)
```

**Sell-Through Simulation:**
```
SellProbability = FastMovingFactor × SeasonalFactor × PriceFactor × RandomFactor

FastMovingFactor: 95% (fast) or 75% (regular)
SeasonalFactor: 85% (Q1) to 135% (Q4)
PriceFactor: 155% (<₦3K) to 110% (>₦6K)
RandomFactor: 50%-100%

IsSold = (SellProbability > 60%)
```

**For Sold Items:**
- Assign DateSoldKey (random operating day after DateAddedKey)
- Calculate DaysInInventory

**Discount Application:**
```
IF IsSold = 0 AND DaysInInventory >= 90 AND IsSalesPeriod = 1:
    IsInDiscount = 1
    DiscountPercent = 25/40/50 (based on age)
    DiscountedPrice = SellingPrice × (1 - Discount%)
    FinalSalePrice = DiscountedPrice
ELSE:
    FinalSalePrice = SellingPrice
```

**Skills Demonstrated:**
- Large-scale data generation (36K rows)
- Multi-factor probability modeling
- Conditional pricing algorithms
- Lifecycle simulation
- Performance optimization (temp tables, batch inserts)

---

##### FactSales (~21,800 transactions)

**Generation Logic:**

**Transaction Grouping:**
- Group sold items by DateSoldKey
- Assign transaction sizes (weighted distribution)
- Create one FactSales row per group

**Transaction Size Distribution:**
- 1 item: 45%
- 2-4 items: 25%
- 5-8 items: 15%
- 9-10 items: 10%
- 11-50 items: 5%

**Payment Method:**
- Cash: 30%
- Transfer: 45%
- POS: 25%

**Recurring Customer:**
- 35% probability

**Transaction Totals:**
```
SubtotalAmount = SUM(FinalSalePrice) for all items
DiscountAmount = SUM(SellingPrice - FinalSalePrice) where discounted
TotalAmount = SubtotalAmount - DiscountAmount
```

**Critical ID Mapping Challenge:**

**Problem:** Need to link items to auto-generated SaleTransactionID

**Solution (MERGE-based):**
```sql
MERGE dbo.FactSales AS tgt
USING (
    SELECT *, ROW_NUMBER() OVER (ORDER BY TempID) AS RowNum
    FROM #TempSales
) AS src
ON 1 = 0  -- Forces INSERT for all rows
WHEN NOT MATCHED THEN INSERT (...)
OUTPUT INSERTED.SaleTransactionID, src.RowNum
INTO @Mapping;

-- Update items with mapped IDs
UPDATE fi
SET SaleTransactionID = m.SaleTransactionID
FROM FactItems fi
JOIN @Mapping m ON fi.TempRowNum = m.RowNum;
```

**Skills Demonstrated:**
- Transaction-level aggregation
- MERGE statement advanced usage
- OUTPUT clause for ID mapping
- Temp table choreography
- Weighted distributions

---

##### FactExpenses (~200 expenses)

**Generation Logic:**

**Recurring Expenses (Monthly):**
- Rent: ₦150K-₦200K (1st of month)
- Staff: ₦80K-₦180K (25th of month)
- Utilities: ₦20K-₦35K (variable dates)

**Non-Recurring Expenses:**
- Transport: ₦5K-₦20K (as needed)
- Other: ₦5K-₦30K (irregular)

**Payment Methods:**
- Rent: Transfer
- Staff: Cash or Transfer
- Others: Mixed

**Skills Demonstrated:**
- Recurring pattern generation
- Category-specific amount ranges
- Payment method variation

---

##### FactCashMovements (~1,200 movements)

**Generation Logic:**

**Account Starting Balances:**
- Profits: ₦250,000
- Operations: ₦100,000
- Debts: ₦0

**Daily Processing for Each Operating Day:**

1. **Sales Revenue (if any):**
   ```
   Profits: DEPOSIT (100% of daily sales)
   ```

2. **Operations Funding:**
   ```
   Profits → Operations: TRANSFER (70% of daily sales)
   ```

3. **Debt Funding:**
   ```
   Operations → Debts: TRANSFER (65% of Operations receipt)
   ```

4. **Expense Payments (if any):**
   ```
   Operations: WITHDRAWAL (expense amount)
   If insufficient, Profits → Operations first
   ```

5. **Loan Repayments (if due):**
   ```
   Debts: WITHDRAWAL (monthly repayment)
   If insufficient, Operations → Debts
   If still insufficient, Profits → Operations → Debts
   ```

6. **Deficit Corrections (in-day):**
   ```
   IF Debts < 0:
       Operations → Debts (ABS(Debts) × 1.10 + ₦1,000)
   
   IF Operations < 0:
       Profits → Operations (ABS(Operations) × 1.10 + ₦1,000)
   ```

7. **Year-End Sweeps (Dec 31 only):**
   ```
   Debts → Profits (all)
   Operations → Profits (excess over ₦500K)
   ```

**Running Balance Calculation:**
```sql
-- For each movement, calculate new balance
RunningBalance = 
    PreviousBalance 
    + (Amount if DEPOSIT or incoming TRANSFER)
    - (Amount if WITHDRAWAL or outgoing TRANSFER)
```

**Skills Demonstrated:**
- Multi-account reconciliation
- Complex procedural logic
- Deficit handling algorithms
- Daily balance tracking
- Transfer relationship modeling
- Date-based conditional logic (year-end)
- Window functions for running totals

---

### Data Quality Assurance

**Constraint Validation:**
- Executed `DBCC CHECKCONSTRAINTS` - 0 violations
- All CHECK constraints satisfied
- All foreign keys valid

**Business Logic Validation:**
- FactBells: TotalItems = Sellable + Unsellable (100%)
- FactSales: TotalAmount = Subtotal - Discount (100%)
- FactCashMovements: Zero negative end-of-day balances (366 days × 3 accounts = 1,098 checks, 0 failures)
- FactItems: Sold items have DateSoldKey, unsold don't (100%)

**Referential Integrity:**
- All foreign keys reference existing rows
- Zero orphan records

**Volume Verification:**
- Expected vs Actual row counts within acceptable ranges
- Distribution analysis matches target percentages

---

### Key Challenges & Solutions

**Challenge 1: FactBells Constraint Violation**
- **Issue:** `TotalItems != SellableItems + UnsellableItems`
- **Root Cause:** UPDATE using old column values
- **Solution:** Two-phase UPDATE (SellableItems first, then UnsellableItems)

**Challenge 2: FactSales ID Mapping**
- **Issue:** OUTPUT clause can't reference source table
- **Solution:** MERGE with `ON 1=0` to access both INSERTED and source columns

**Challenge 3: FactItems Sell-Through Tuning**
- **Issue:** Initial model produced unrealistic 40% sell-through
- **Iterations:** Adjusted factors 3 times to reach realistic 60-75%
- **Solution:** Increased seasonal factors, improved price sensitivity

**Challenge 4: FactCashMovements Negative Balances**
- **Issue:** End-of-day balances going negative despite corrections
- **Root Cause:** Corrections happening after additional transactions
- **Solution:** In-day corrections immediately after each balance calculation

**Challenge 5: FactItems Performance**
- **Issue:** 36K row generation taking 10+ minutes
- **Solution:** Temp table with batch inserts instead of row-by-row

---

## Phase 3: Power BI Dashboards 🔄 IN PROGRESS

**Objective:** Build interactive dashboards for business intelligence

**Status:** Not yet started (repository preparation first)

**Planned Duration:** 2-3 weeks

---

### Planned Dashboards

#### 1. Sales Performance Dashboard

**Metrics:**
- Daily/Weekly/Monthly revenue trends
- Year-to-date vs targets
- Average transaction value
- Items per transaction
- Payment method breakdown

**Visualizations:**
- Line chart: Revenue over time
- Bar chart: Revenue by category
- Pie chart: Payment method distribution
- KPI cards: Total revenue, transactions, items sold
- Table: Top-selling subcategories

**Filters:**
- Date range
- Category
- Payment method
- Sales period (on/off)

---

#### 2. Inventory Management Dashboard

**Metrics:**
- Current inventory levels
- Sell-through rate by category
- Average days in inventory
- Discount effectiveness
- Aging analysis

**Visualizations:**
- Stacked bar: Sold vs Unsold by category
- Line chart: Sell-through rate over time
- Heat map: Inventory aging buckets
- Gauge: Overall sell-through percentage
- Table: Slow-moving items (180+ days)

**Filters:**
- Category
- Grade
- Date added range
- Sold status

---

#### 3. Financial Performance Dashboard

**Metrics:**
- Profit & loss statement
- Cash flow summary
- Account balances over time
- Expense breakdown
- Loan repayment status

**Visualizations:**
- Waterfall chart: P&L components
- Area chart: Account balances over time
- Donut chart: Expense categories
- Bar chart: Monthly expenses by category
- KPI cards: Current account balances, total profit

**Filters:**
- Date range
- Account type
- Expense category

---

#### 4. Loan Management Dashboard

**Metrics:**
- Active vs closed loans
- Total outstanding balance
- Repayment schedule compliance
- Interest paid vs principal
- Loan-funded vs profit-funded inventory

**Visualizations:**
- Table: Loan details with status
- Bar chart: Outstanding balance by loan
- Line chart: Cumulative repayments
- Pie chart: Loan vs profit funding
- Gauge: On-time payment percentage

**Filters:**
- Loan status
- Duration
- Date range

---

#### 5. Operational Efficiency Dashboard

**Metrics:**
- Bell performance (ROI)
- Cost per item trends
- Markup effectiveness
- Discount impact on sell-through
- Category profitability

**Visualizations:**
- Scatter plot: Cost vs Sell-through by category
- Bar chart: Average markup by category
- Line chart: Discount rate vs sell-through
- Table: Bell-level profitability
- KPI cards: Average cost per item, average markup

**Filters:**
- Category
- Bell size
- Funding source
- Date range

---

### Technical Implementation

**Data Model:**
- Import star schema from SQL Server
- Establish relationships (auto-detect + manual verification)
- Create date hierarchy (Year → Quarter → Month → Day)
- Define measures in DAX

**Key DAX Measures:**

```dax
// Revenue
Total Revenue = SUM(FactSales[TotalAmount])
YTD Revenue = TOTALYTD([Total Revenue], DimDate[FullDate])

// Sell-Through
Sell Through % = 
    DIVIDE(
        COUNTROWS(FILTER(FactItems, FactItems[IsSold] = 1)),
        COUNTROWS(FactItems),
        0
    ) * 100

// Average Transaction Value
Avg Transaction Value = 
    DIVIDE([Total Revenue], COUNTROWS(FactSales), 0)

// Profit Margin
Gross Profit = 
    SUM(FactSales[TotalAmount]) - 
    SUMX(
        FactItems,
        RELATED(FactItems[CostPerItem])
    )

Profit Margin % = DIVIDE([Gross Profit], [Total Revenue], 0) * 100

// Inventory Metrics
Avg Days in Inventory = AVERAGE(FactItems[DaysInInventory])

Current Inventory Value = 
    SUMX(
        FILTER(FactItems, FactItems[IsSold] = 0),
        FactItems[CostPerItem]
    )
```

**Interactivity:**
- Slicers for all major dimensions
- Cross-filtering between visuals
- Drill-through to detail pages
- Bookmarks for view switching
- Tooltips with additional context

---

### Data Refresh Strategy

**Initial Load:**
- Import full dataset (~60K rows, ~20 MB)
- Refresh time: <2 minutes

**Ongoing Refresh:**
- Scheduled daily refresh (morning)
- Incremental refresh for FactItems, FactSales (if growth continues)
- Full refresh for dimensions (static/low-change)

---

### Publishing & Sharing

**Power BI Service:**
- Publish to workspace
- Configure scheduled refresh
- Set up row-level security (if needed for multi-user)
- Create app for end users

**Embedding Options:**
- Embed in SharePoint
- Share link with stakeholders
- Export to PowerPoint for presentations

---

### Success Criteria

**Dashboard Performance:**
- Load time <5 seconds
- Filter/slicer response <1 second
- Visual refresh <2 seconds

**Business Value:**
- Answers key business questions without SQL
- Accessible to non-technical stakeholders
- Actionable insights visible at a glance
- Reduces ad-hoc query requests by 80%

---

## Skills Progression

### Phase 1 Skills
- Database design & architecture
- SQL DDL (CREATE TABLE, constraints, indexes)
- Star schema dimensional modeling
- Referential integrity
- Performance optimization

### Phase 2 Skills
- SQL DML (INSERT, UPDATE, MERGE)
- Procedural SQL (temp tables, CTEs, loops)
- Random data generation
- Weighted distributions
- Complex business logic implementation
- Data quality validation
- Performance tuning for bulk operations

### Phase 3 Skills (Planned)
- Power BI desktop development
- DAX measure creation
- Data modeling in Power BI
- Visual design & UX
- Dashboard interactivity
- Power BI Service publishing
- Report sharing & collaboration

---

## Project Metrics

### Development Time

| Phase | Estimated Solo | Actual with AI | Time Savings |
|-------|---------------|----------------|--------------|
| Phase 1 | 8-12 hours | 4 hours | 60% |
| Phase 2 | 30-40 hours | 12 hours | 65% |
| Phase 3 | TBD | TBD | TBD |
| **Total** | **38-52 hours** | **16 hours** | **~65%** |

### Code Statistics

| Metric | Count |
|--------|-------|
| SQL Files | 12+ |
| Lines of SQL | ~10,000 |
| Database Objects | 67 (12 tables, 50+ indexes, 5+ constraints per table) |
| Synthetic Records | ~60,000 |
| Data Size | ~20 MB |

---

## Portfolio Value Proposition

**For Technical Recruiters:**
- ✅ Production-grade SQL development
- ✅ Large-scale synthetic data generation
- ✅ Complex business logic implementation
- ✅ Performance optimization
- ✅ Data quality assurance

**For Business Stakeholders:**
- ✅ Real-world business problem solving
- ✅ Lagos market context (local relevance)
- ✅ Financial domain expertise
- ✅ End-to-end solution design

**For AI/Tech Communities:**
- ✅ Transparent AI collaboration
- ✅ Human-AI decision framework
- ✅ Documented problem-solving process
- ✅ Quantified productivity gains
- ✅ Lessons learned & best practices

---

## Next Actions

**Immediate (Post-GitHub Upload):**
1. ✅ Finalize repository structure
2. ✅ Write comprehensive README
3. ✅ Document AI collaboration methodology
4. ⬜ Push to GitHub
5. ⬜ Update LinkedIn/portfolio

**Short-Term (Next 2-3 Weeks):**
1. ⬜ Begin Phase 3 (Power BI dashboards)
2. ⬜ Create sample dashboard screenshots
3. ⬜ Record demo video walkthrough
4. ⬜ Write blog post on development process

**Long-Term (Next 2-3 Months):**
1. ⬜ Present project at local meetup
2. ⬜ Create tutorial series (video/written)
3. ⬜ Open-source additional tools/scripts
4. ⬜ Explore advanced analytics (ML predictions)

---

## Conclusion

The Amazing Grace Store Data Warehouse project demonstrates a complete, end-to-end approach to business intelligence development:

- **Phase 1** established solid foundations with production-grade schema design
- **Phase 2** brought the warehouse to life with realistic synthetic data
- **Phase 3** will democratize insights through interactive dashboards

Each phase builds critical skills while showcasing the ability to deliver real business value through data engineering and analytics.

---

**Author:** Ibeh Chidera Elijah  
**GitHub:** [@Elijjjaaaahhhhh](https://github.com/Elijjjaaaahhhhh)  
**Project:** Amazing Grace Store Data Warehouse  
**Location:** Lagos, Nigeria  
**Date:** February 2026
