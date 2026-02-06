# Business Rules Documentation

## Overview

This document defines the complete business logic for Amazing Grace Store, a second-hand clothing retail business in Lagos, Nigeria. All rules are enforced at the database level through CHECK constraints, foreign keys, and generation logic.

---

## Store Operations

### Operating Calendar

**Store Opening Date:** January 4, 2024 (Thursday)

**Regular Schedule:**
- **Open:** Monday - Saturday
- **Closed:** Every Sunday

**Holiday Closures:**
- Good Friday: March 29, 2024
- Easter Monday: April 1, 2024
- Christmas period: December 25-27, 2024

**Operating Days:** ~306 days per year
- 365 days (leap year 2024)
- Minus 52 Sundays
- Minus 7 holiday closures
- Minus 3 pre-opening days (Jan 1-3)

**Implementation:**
```sql
IsStoreOpen = CASE 
    WHEN DATENAME(WEEKDAY, FullDate) = 'Sunday' THEN 0
    WHEN FullDate < '2024-01-04' THEN 0
    WHEN FullDate = '2024-03-29' THEN 0  -- Good Friday
    WHEN FullDate = '2024-04-01' THEN 0  -- Easter Monday
    WHEN FullDate BETWEEN '2024-12-25' AND '2024-12-27' THEN 0
    ELSE 1
END
```

---

### Sales Periods

**Discount Sales Windows:** 3 weeks each

1. **February Sale:** February 5-25 (21 days)
2. **Mid-Year Sale:** June 3-23 (21 days)
3. **Pre-Holiday Sale:** November 4-24 (21 days)

**Non-Sale Periods:**
- Discounts NOT applied even if items meet age criteria
- Full price sales only

**Implementation:**
```sql
IsSalesPeriod = CASE 
    WHEN FullDate BETWEEN '2024-02-05' AND '2024-02-25' THEN 1
    WHEN FullDate BETWEEN '2024-06-03' AND '2024-06-23' THEN 1
    WHEN FullDate BETWEEN '2024-11-04' AND '2024-11-24' THEN 1
    ELSE 0
END
```

---

### Peak Periods

**High-Traffic Times:**
- End of each month (payday for salaried workers)
- University resumption periods (Sept-Oct, Jan-Feb)
- Summer holidays (July-August)

**Business Impact:**
- Higher foot traffic
- Increased transaction sizes
- Better sell-through rates

---

## Inventory Management

### Bells (Bulk Purchases)

**Definition:** A "bell" is a bulk purchase of second-hand clothing items, typically in large bags or containers.

**Bell Sizes:**
| Size | Minimum Items | Maximum Items | Cost Range (₦) |
|------|--------------|---------------|----------------|
| Small | 200 | 250 | 350,000 - 450,000 |
| Medium | 300 | 350 | 500,000 - 650,000 |
| Large | 400 | 500 | 700,000 - 850,000 |

**Size Distribution:**
- Small: 30%
- Medium: 40%
- Large: 30%

**Constraint:**
```sql
CHECK (BellCost BETWEEN 350000 AND 850000)
```

---

### Category Distribution

**Bell Composition (Weighted Random):**

| Category | Percentage | Rationale |
|----------|-----------|-----------|
| Tops | 25% | Universal demand, quick turnover |
| Bottoms | 30% | Essential wardrobe item |
| Outerwear | 15% | Seasonal, higher price point |
| Activewear | 20% | Growing fitness culture |
| Dresses | 10% | Niche market, gender-specific |

**Implementation:**
```sql
CASE 
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 25 THEN 1  -- Tops
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 55 THEN 2  -- Bottoms (25+30=55)
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 3  -- Outerwear (55+15=70)
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 90 THEN 4  -- Activewear (70+20=90)
    ELSE 5  -- Dresses (remaining 10%)
END AS CategoryID
```

---

### Sellable vs. Unsellable Items

**Sellable Percentage:** 65% - 90% of total items in a bell

**Factors Affecting Percentage:**
- Bell quality (random variation)
- Category (some categories have higher damage rates)
- Bell size (larger bells may have more variation)

**Unsellable Items:**
- Damaged beyond repair
- Severe stains
- Missing critical components (zippers, buttons)
- Not disposed but not tracked in FactItems

**Critical Constraint:**
```sql
CHECK (TotalItems = SellableItems + UnsellableItems)
```

**Implementation (Two-Phase Update):**
```sql
-- Phase 1: Calculate sellable items
UPDATE FactBells
SET SellableItems = CAST(TotalItems * SellablePercentage AS INT);

-- Phase 2: Calculate unsellable (uses NEW SellableItems value)
UPDATE FactBells
SET UnsellableItems = TotalItems - SellableItems;
```

---

### Cost Allocation

**Cost Per Item Calculation:**
```
CostPerItem = BellCost / SellableItems
```

**Rationale:**
- Only sellable items generate revenue
- Unsellable items absorbed as cost of business
- Transport cost included in bell cost

**Transport Cost:**
- ₦12,000 per trip
- 3-6 bells per trip (based on proximity)
- Allocated: TransportCost ÷ BellsInTrip

---

## Financing Structure

### Loan Parameters

**Principal Amount:**
- Minimum: ₦2,000,000
- Maximum: ₦8,000,000
- Increment: ₦500,000
- Valid amounts: ₦2M, ₦2.5M, ₦3M, ..., ₦8M

**Loan Duration:**
- 6 months
- 12 months
- No other durations allowed

**Interest Rates:**
- Range: 12% - 18% annual
- Reflects Lagos microfinance market rates
- Higher amounts may get lower rates
- Longer duration may have higher rates

**Constraint:**
```sql
CHECK (PrincipalAmount BETWEEN 2000000 AND 8000000)
CHECK (PrincipalAmount % 500000 = 0)  -- Increment check
CHECK (DurationMonths IN (6, 12))
CHECK (EffectiveInterestRate BETWEEN 0.12 AND 0.18)
```

---

### Loan Repayment

**Monthly Repayment Calculation:**
```
MonthlyRepayment = (PrincipalAmount × (1 + InterestRate)) / DurationMonths
```

**Payment Status Distribution:**
- OnTime: 90% (within 3 days of due date)
- Late: 7% (3+ days after due date)
- Partial: 3% (less than scheduled amount)

**Late Payment Threshold:** 3 days past scheduled date

**Partial Payment:**
- ActualAmount < ScheduledAmount
- DaysLate may also be > 0

**Constraint:**
```sql
CHECK (PaymentStatus IN ('OnTime', 'Late', 'Partial'))
```

---

### Bell Financing Mix

**Funding Sources:**
- Loan-funded: 60% of bells
- Profit-funded: 40% of bells

**Loan Allocation:**
- Each loan funds 8-12 bells
- Bells purchased within 60 days of loan disbursement
- LoanID populated for loan-funded bells
- LoanID NULL for profit-funded bells

**Business Logic:**
```sql
IsProfitFunded = CASE WHEN LoanID IS NULL THEN 1 ELSE 0 END
```

---

## Pricing Strategy

### Item Grading

**Grade Distribution:**
- Grade 1 (Premium): 70% of inventory
- Grade 2 (Standard): 30% of inventory

**Grade Determination:**
- Based on condition, brand, style
- Grade 1 eligible for top-tier designation
- Grade 2 never top-tier

**Constraint:**
```sql
CHECK (GradeID IN (1, 2))
```

---

### Top-Tier Items

**Eligibility:** Only Grade 1 items

**Selection Rate:** 15% of Grade 1 items
- Calculation: 70% × 15% = 10.5% of total inventory

**Characteristics:**
- Designer brands
- Excellent condition
- Current fashion trends
- High market demand

**Pricing Impact:** 50% markup (vs. 20-30% standard)

---

### Markup Percentages

**Standard Items:**
- Range: 20% - 30%
- Varies by category and market conditions

**Top-Tier Items:**
- Fixed: 50%
- Premium positioning

**Formula:**
```
BasePrice = CostPerItem × (1 + MarkupPercent)
SellingPrice = BasePrice (may be discounted later)
```

**Constraint:**
```sql
CHECK (ActualMarkupPercent BETWEEN 20 AND 50)
```

---

### Discount Structure

**Age-Based Discount Tiers:**

| Days in Inventory | Discount % | Rationale |
|------------------|-----------|-----------|
| 0 - 89 | 0% | Fresh inventory, full price |
| 90 - 119 | 25% | Moderate aging, gentle discount |
| 120 - 179 | 40% | Extended aging, aggressive discount |
| 180+ | 50% | Maximum discount to clear inventory |

**Eligibility Rules:**
1. Item must be unsold
2. Must be within a sales period (Feb, Jun, Nov)
3. Must meet minimum age threshold (90 days)

**Discount Application:**
```sql
IsInDiscount = CASE 
    WHEN IsSold = 0 
         AND DaysInInventory >= 90 
         AND IsSalesPeriod = 1 
    THEN 1 
    ELSE 0 
END

DiscountPercent = CASE 
    WHEN DaysInInventory BETWEEN 90 AND 119 THEN 25
    WHEN DaysInInventory BETWEEN 120 AND 179 THEN 40
    WHEN DaysInInventory >= 180 THEN 50
    ELSE NULL
END

DiscountedPrice = SellingPrice × (1 - DiscountPercent/100)
FinalSalePrice = COALESCE(DiscountedPrice, SellingPrice)
```

**Constraint:**
```sql
CHECK (DiscountPercent IN (25, 40, 50) OR DiscountPercent IS NULL)
```

---

## Sell-Through Simulation

### Probability Model

**Formula:**
```
SellProbability = FastMovingFactor × SeasonalFactor × PriceFactor × RandomFactor
```

**Decision Rule:**
```
IF SellProbability > 60% THEN IsSold = 1 ELSE IsSold = 0
```

---

### Fast-Moving Factor

**Fast-Moving Items:**
- Probability: 95%
- Examples: T-shirts, jeans, hoodies
- Flag: `DimSubcategories.IsFastMoving = 1`

**Regular Items:**
- Probability: 75%
- Examples: Suits, evening dresses, formal wear

---

### Seasonal Factor

**Quarterly Variation:**

| Quarter | Months | Factor | Rationale |
|---------|--------|--------|-----------|
| Q1 | Jan-Mar | 85% | Post-holiday slowdown |
| Q2 | Apr-Jun | 105% | Spring shopping uptick |
| Q3 | Jul-Sep | 120% | Back-to-school peak |
| Q4 | Oct-Dec | 135% | Holiday season maximum |

**Implementation:**
```sql
CASE 
    WHEN MONTH(DateAdded) BETWEEN 1 AND 3 THEN 0.85
    WHEN MONTH(DateAdded) BETWEEN 4 AND 6 THEN 1.05
    WHEN MONTH(DateAdded) BETWEEN 7 AND 9 THEN 1.20
    WHEN MONTH(DateAdded) BETWEEN 10 AND 12 THEN 1.35
END AS SeasonalFactor
```

---

### Price Factor

**Price Sensitivity:**

| Price Range (₦) | Factor | Market Segment |
|----------------|--------|----------------|
| < 3,000 | 155% | Budget-conscious, high demand |
| 3,000 - 6,000 | 130% | Mid-market, moderate |
| > 6,000 | 110% | Premium, selective |

**Rationale:**
- Lower-priced items move faster
- Budget segment larger in Lagos market
- Premium items appeal to smaller audience

**Implementation:**
```sql
CASE 
    WHEN SellingPrice < 3000 THEN 1.55
    WHEN SellingPrice BETWEEN 3000 AND 6000 THEN 1.30
    WHEN SellingPrice > 6000 THEN 1.10
END AS PriceFactor
```

---

### Random Factor

**Range:** 50% - 100%

**Purpose:**
- Introduces natural variation
- Prevents identical items from having identical outcomes
- Simulates unpredictable market factors

**Implementation:**
```sql
((ABS(CHECKSUM(NEWID())) % 50) + 50) / 100.0 AS RandomFactor
```

**Why not 0-100%?**
- Ensures minimum baseline (50%)
- Items with strong fundamentals still likely to sell
- Prevents excessive unsold inventory

---

### Expected Sell-Through Rates

**Overall Target:** 60-75% of inventory sold

**By Category:**
- Fast-moving tops (T-shirts): 80-90%
- Regular bottoms (Jeans): 70-80%
- Activewear: 75-85%
- Outerwear: 60-70%
- Dresses: 50-60%

**By Quarter:**
- Q1: Lower sell-through (~60%)
- Q4: Higher sell-through (~80%)

---

## Sales Transactions

### Transaction Grouping

**Critical Rule:** Items grouped ONLY by same sale date (DateSoldKey)

**Not grouped by:**
- Same customer (not tracked)
- Same payment method (varies)
- Same time window (date only)

**Implementation:**
```sql
-- Items assigned to transactions via PARTITION BY DateSoldKey
ROW_NUMBER() OVER (PARTITION BY DateSoldKey ORDER BY ItemID)
```

**Verification:**
```sql
-- Each transaction should have COUNT(DISTINCT DateSoldKey) = 1
SELECT SaleTransactionID, COUNT(DISTINCT DateSoldKey)
FROM FactItems
WHERE IsSold = 1
GROUP BY SaleTransactionID
HAVING COUNT(DISTINCT DateSoldKey) > 1;
-- Should return 0 rows
```

---

### Transaction Size Distribution

**Item Count per Transaction:**

| Items | Probability | Typical Customer |
|-------|------------|------------------|
| 1 | 45% | Single-item buyers |
| 2-4 | 25% | Small basket |
| 5-8 | 15% | Medium basket |
| 9-10 | 10% | Large basket |
| 11-50 | 5% | Bulk buyers (resellers) |

**Implementation:**
```sql
CASE 
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 45 THEN 1
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 70 THEN 2 + (ABS(CHECKSUM(NEWID())) % 3)  -- 2-4
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 85 THEN 5 + (ABS(CHECKSUM(NEWID())) % 4)  -- 5-8
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 95 THEN 9 + (ABS(CHECKSUM(NEWID())) % 2)  -- 9-10
    ELSE 11 + (ABS(CHECKSUM(NEWID())) % 40)  -- 11-50
END AS ItemsPerTransaction
```

---

### Payment Methods

**Distribution:**
- Cash: 30%
- Bank Transfer: 45%
- POS (Debit/Credit Card): 25%

**Rationale:**
- Transfers most popular (instant confirmation, no cash handling)
- Cash still significant (Lagos market preference)
- POS growing but requires terminal

**Constraint:**
```sql
CHECK (PaymentMethod IN ('Cash', 'Transfer', 'POS'))
```

---

### Recurring Customers

**Definition:** Customers who have made previous purchases

**Probability:** 35% of all transactions

**Implementation:**
```sql
IsRecurringCustomer = CASE 
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 35 THEN 1 
    ELSE 0 
END
```

**Business Implication:**
- 35% customer retention rate
- Indicates repeat business health
- Not tracked per-customer (anonymized)

---

### Transaction Amounts

**Calculation:**
```
SubtotalAmount = SUM(FinalSalePrice) for all items in transaction
DiscountAmount = SUM(SellingPrice - DiscountedPrice) where applicable
TotalAmount = SubtotalAmount - DiscountAmount
```

**Constraint:**
```sql
CHECK (TotalAmount = SubtotalAmount - DiscountAmount)
```

**Verification:**
```sql
SELECT 
    SaleTransactionID,
    SubtotalAmount,
    DiscountAmount,
    TotalAmount
FROM FactSales
WHERE TotalAmount != (SubtotalAmount - DiscountAmount);
-- Should return 0 rows
```

---

## Operating Expenses

### Expense Categories

**1. Rent**
- Amount: ₦150,000 - ₦200,000/month
- Frequency: Monthly (1st of each month)
- IsRecurring: TRUE
- Payment: Transfer

**2. Staff Salaries**
- Employees: 2-3 staff members
- Amount per staff: ₦40,000 - ₦60,000/month
- Total: ₦80,000 - ₦180,000/month
- Frequency: Monthly (25th of each month)
- IsRecurring: TRUE
- Payment: Cash or Transfer

**3. Utilities**
- Electricity: ₦15,000 - ₦25,000/month
- Water: ₦5,000 - ₦10,000/month
- Total: ₦20,000 - ₦35,000/month
- Frequency: Monthly (variable dates)
- IsRecurring: TRUE
- Payment: Cash or Transfer

**4. Transport**
- Operational transport (not bell purchases)
- Amount: ₦5,000 - ₦20,000/occurrence
- Frequency: As needed
- IsRecurring: FALSE
- Payment: Cash

**5. Other**
- Security, cleaning, maintenance
- Amount: ₦5,000 - ₦30,000/occurrence
- Frequency: Irregular
- IsRecurring: FALSE
- Payment: Cash or Transfer

**Constraint:**
```sql
CHECK (ExpenseCategory IN ('Rent','Staff','Utilities','Transport','Other'))
CHECK (PaymentMethod IN ('Cash', 'Transfer'))
```

---

### Monthly Operating Expenses

**Estimated Range:** ₦250,000 - ₦450,000/month

**Breakdown:**
- Fixed costs (Rent + Staff + Utilities): ₦250,000 - ₦415,000
- Variable costs (Transport + Other): ₦0 - ₦50,000

**Annual Operating Expenses:** ~₦3M - ₦5M

---

## Cash Flow Management

### Three-Account System

**1. Profits Account**
- **Purpose:** Revenue accumulation
- **Starting Balance:** ₦250,000
- **Inflows:** 100% of daily sales
- **Outflows:** Transfers to Operations, loan repayments (if needed)
- **Target:** Maximum accumulation

**2. Operations Account**
- **Purpose:** Working capital for daily operations
- **Starting Balance:** ₦100,000
- **Inflows:** 70% of daily sales (transferred from Profits)
- **Outflows:** Operating expenses, transfers to Debts
- **Target:** Maintain ₦100,000 - ₦500,000

**3. Debts Account**
- **Purpose:** Loan repayment fund
- **Starting Balance:** ₦0
- **Inflows:** 65% of Operations receipts, deficit corrections
- **Outflows:** Loan repayments
- **Target:** Sufficient to cover monthly repayments

---

### Daily Cash Flow Rules

**Step 1: Sales Revenue Processing**
```
1. Daily Sales → Profits (100%)
   Type: DEPOSIT
   Description: "Daily sales revenue"
```

**Step 2: Operations Funding**
```
2. Profits → Operations (70% of daily sales)
   Type: TRANSFER
   Description: "Daily operations funding"
```

**Step 3: Debt Funding**
```
3. Operations → Debts (65% of Operations receipt)
   Type: TRANSFER
   Description: "Daily debt allocation"
```

---

### Deficit Correction Rules

**Critical Rule:** No account should EVER end a day with negative balance

**If Debts Balance < 0:**
```
Correction Amount = ABS(DebtsBalance) × 1.10 + ₦1,000

Operations → Debts (TRANSFER)
Description: "Deficit correction for Debts account"

Check Operations Balance After Transfer
```

**If Operations Balance < 0 (after Debts correction):**
```
Correction Amount = ABS(OperationsBalance) × 1.10 + ₦1,000

Profits → Operations (TRANSFER)
Description: "Deficit correction for Operations account"

Check Profits Balance After Transfer
```

**Buffer Logic:**
- **10% buffer:** Prevents immediate re-deficit on next transaction
- **₦1,000 addition:** Ensures positive balance even for tiny deficits
- **In-day correction:** Applied immediately, not end-of-day

**Example:**
```
Debts Balance: -₦15,000
Correction: (15,000 × 1.10) + 1,000 = ₦17,500
Operations → Debts: ₦17,500
New Debts Balance: ₦2,500 ✓
```

---

### Expense Payments

**From Operations Account:**
- Rent
- Staff Salaries
- Utilities
- Transport
- Other

**Process:**
```
Operations → Withdrawal (Amount)
Type: WITHDRAWAL
Description: "[Expense Category] - [Description]"
```

**Exception Handling:**
- If Operations insufficient, Profits supplements first
- Then expense withdrawn

---

### Loan Repayments

**From Debts Account:**
```
Debts → Withdrawal (MonthlyRepayment)
Type: WITHDRAWAL
Description: "Loan repayment - Loan ID [X]"
```

**Timing:** On or before scheduled repayment date

**If Insufficient Funds:**
1. Operations → Debts (supplement)
2. If still insufficient, Profits → Operations → Debts
3. Ensures repayment can always be made

---

### Year-End Account Sweeps

**December 31 Only:**

**Step 1: Clear Debts Account**
```
IF DebtsBalance > 0:
   Debts → Profits (DebtsBalance)
   Type: TRANSFER
   Description: "Year-end sweep - Debts to Profits"
   
New Debts Balance: ₦0
```

**Step 2: Maintain Operations Buffer**
```
IF OperationsBalance > 500,000:
   Excess = OperationsBalance - 500,000
   Operations → Profits (Excess)
   Type: TRANSFER
   Description: "Year-end sweep - Excess Operations to Profits"
   
Target Operations Balance: ₦0 - ₦500,000
```

**Step 3: Accumulate in Profits**
```
Profits receives all remainder
No maximum limit
```

**Rationale:**
- Start new year with clean slate
- Debts ready for new loans
- Operations has working capital
- Profits shows annual profitability

---

### Movement Types

**DEPOSIT:**
- External funds entering account
- Examples: Sales revenue, loan disbursement

**WITHDRAWAL:**
- Funds leaving account externally
- Examples: Expenses, loan repayments

**TRANSFER:**
- Funds moving between accounts
- Requires SourceAccount AND DestinationAccount
- Examples: Daily flows, deficit corrections, year-end sweeps

**Constraint:**
```sql
CHECK (MovementType IN ('Deposit', 'Withdrawal', 'Transfer'))
CHECK (
    (MovementType = 'Transfer' AND SourceAccount IS NOT NULL AND DestinationAccount IS NOT NULL) OR
    (MovementType IN ('Deposit', 'Withdrawal') AND SourceAccount IS NULL AND DestinationAccount IS NULL)
)
```

---

### Running Balance Calculation

**Formula:**
```
RunningBalance = PreviousBalance + Amount (for DEPOSIT/TRANSFER to this account)
RunningBalance = PreviousBalance - Amount (for WITHDRAWAL/TRANSFER from this account)
```

**Implementation:**
```sql
-- Calculate within day, per account
RunningBalance = 
    StartOfDayBalance 
    + SUM(Deposits and Incoming Transfers)
    - SUM(Withdrawals and Outgoing Transfers)
```

**Validation:**
```sql
-- No negative end-of-day balances
SELECT 
    MovementDateKey,
    AccountType,
    MAX(RunningBalance) OVER (
        PARTITION BY MovementDateKey, AccountType 
        ORDER BY CashMovementID DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS EndOfDayBalance
FROM FactCashMovements
WHERE EndOfDayBalance < 0;
-- Should return 0 rows
```

---

## Data Quality Rules

### Referential Integrity

**All Foreign Keys Must Be Satisfied:**
- Every DateKey exists in DimDate
- Every CategoryID exists in DimCategories
- Every SubcategoryID exists in DimSubcategories
- Every BellID exists in FactBells
- Every LoanID (not NULL) exists in FactLoans
- Every SaleTransactionID (not NULL) exists in FactSales

**Orphan Records Not Allowed**

---

### Data Consistency

**FactBells:**
```sql
-- Items must sum correctly
TotalItems = SellableItems + UnsellableItems (always)

-- Cost per item must be calculated
CostPerItem = BellCost / SellableItems (always)

-- Loan-funded bells must have LoanID
IsProfitFunded = 0 IMPLIES LoanID IS NOT NULL
```

**FactItems:**
```sql
-- Sold items must have sale date
IsSold = 1 IMPLIES DateSoldKey IS NOT NULL

-- Unsold items must NOT have sale date
IsSold = 0 IMPLIES DateSoldKey IS NULL

-- Discounted items must have discount
IsInDiscount = 1 IMPLIES DiscountPercent IS NOT NULL
```

**FactSales:**
```sql
-- Transaction total must match items
TotalItems = COUNT(FactItems WHERE SaleTransactionID = this transaction)

-- Amount must balance
TotalAmount = SubtotalAmount - DiscountAmount (always)
```

**FactCashMovements:**
```sql
-- No negative balances at end of day (critical)
RunningBalance >= 0 (for all end-of-day balances)

-- Transfers must have both accounts
MovementType = 'Transfer' IMPLIES SourceAccount IS NOT NULL AND DestinationAccount IS NOT NULL
```

---

## Summary of Critical Business Rules

1. **Store operates 306 days/year** - Closed Sundays and holidays
2. **60% loan-funded, 40% profit-funded** inventory
3. **70% Grade 1, 30% Grade 2** items
4. **15% of Grade 1 are top-tier** (50% markup)
5. **Standard markup: 20-30%**, top-tier: 50%
6. **Discounts: 25%/40%/50%** based on age (90/120/180 days)
7. **Sell-through: 60-75%** overall, varies by category/season/price
8. **Transaction sizes: 45% single item**, 55% multiple items
9. **Payment methods: 30% Cash, 45% Transfer, 25% POS**
10. **Daily cash flow: Sales → Profits → Operations → Debts** (100% → 70% → 65%)
11. **Deficit corrections: 10% buffer + ₦1,000** (in-day)
12. **Year-end sweeps: Debts→₦0, Operations→₦0-500K, Profits→remainder**
13. **No negative balances ever** - enforced through deficit correction
14. **Items grouped only by same sale date** in transactions

---

**Author:** Ibeh Chidera Elijah  
**Project:** Amazing Grace Store Data Warehouse  
**Date:** February 2026  
**Currency:** Nigerian Naira (₦)  
**Location:** Lagos, Nigeria
