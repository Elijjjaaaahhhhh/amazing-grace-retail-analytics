# Amazing Grace Store - Data Warehouse & Analytics

> A production-grade SQL Server 2022 data warehouse showcasing dimensional modeling, synthetic data generation, and AI-augmented development workflow for a Lagos-based second-hand clothing retail business.

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-CC2927?logo=microsoft-sql-server)](https://www.microsoft.com/en-us/sql-server)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Phase](https://img.shields.io/badge/Phase-2%20Complete-green)](docs/PROJECT_PHASES.md)

---

## 🎯 Project Overview

This project demonstrates the complete lifecycle of building a data warehouse from scratch, combining traditional SQL expertise with modern AI-assisted development practices. Built for **Amazing Grace Store**, a Lagos, Nigeria-based clothing retail business, this warehouse manages inventory, sales, loans, and financial operations.

### Key Metrics
- **Database Size:** ~100,000+ records
- **Tables:** 12 (5 dimensions, 7 facts)
- **Architecture:** Star Schema
- **Annual Volume:** 36,000+ items, 21,000+ transactions
- **Location:** Lagos, Nigeria 🇳🇬
- **Currency:** Nigerian Naira (₦)

---

## 💼 Business Context

**Amazing Grace Store** operates a second-hand clothing retail business in Lagos with unique operational characteristics:

- **Inventory Model:** Bulk purchases called "bells" (200-500 items each)
- **Financing:** Mix of loan-funded (60%) and profit-funded (40%) inventory
- **Product Mix:** Tops, Bottoms, Outerwear, Activewear, Dresses
- **Grading System:** Grade 1 (70% of inventory) and Grade 2 (30%)
- **Operating Schedule:** Open Monday-Saturday, closed Sundays and Christian holidays
- **Financial Tracking:** 3 separate savings accounts (Profits, Operations, Debts)

---

## 🏗️ Architecture

### Star Schema Design

```
           ┌─────────────┐
           │   DimDate   │
           │  (366 rows) │
           └──────┬──────┘
                  │
     ┌────────────┼────────────┐
     │            │            │
┌────▼─────┐ ┌───▼────┐ ┌────▼─────┐
│ DimCateg │ │DimSizes│ │DimGrades │
│(5 rows)  │ │(3 rows)│ │(2 rows)  │
└────┬─────┘ └───┬────┘ └────┬─────┘
     │           │            │
     │      ┌────▼────────────▼────┐
     │      │  DimSubcategories    │
     │      │     (47 rows)        │
     └──────┴──────────┬───────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
     ┌────▼─────┐ ┌───▼────┐ ┌────▼─────┐
     │FactBells │ │FactLoan│ │FactExpns │
     │(~130)    │ │  (8)   │ │ (~200)   │
     └────┬─────┘ └───┬────┘ └──────────┘
          │           │
          ▼           ▼
     ┌────────┐ ┌─────────┐
     │FactItem│ │FactLoan │
     │(36,000)│ │Repay(70)│
     └────┬───┘ └─────────┘
          │
          ▼
     ┌─────────┐
     │FactSale │
     │(21,800) │
     └─────────┘
```

### Data Flow
1. **Bells** purchased → Individual **Items** created
2. **Items** sold → Grouped into **Sales** transactions
3. **Loans** disbursed → **Repayments** tracked
4. All financial movements → **Cash** tracking

---

## 📊 Database Statistics

| Entity | Row Count | Complexity | Business Logic |
|--------|-----------|------------|----------------|
| **DimDate** | 366 | Store calendar | Leap year 2024, closed Sundays, Christian holidays |
| **DimCategories** | 5 | Product types | Tops, Bottoms, Outerwear, Activewear, Dresses |
| **DimSubcategories** | 47 | Item variants | Gender-specific, fast-moving flags |
| **DimBellSizes** | 3 | Inventory tiers | Small (200-250), Medium (300-350), Large (400-500) |
| **DimItemGrades** | 2 | Quality tiers | Grade 1 (top-tier eligible), Grade 2 |
| **FactLoans** | 8 | Financing | ₦2M-₦8M principals, 6-12 month terms, 12-18% APR |
| **FactLoanRepayments** | ~70 | Payments | 90% on-time, 7% late, 3% partial |
| **FactBells** | ~130 | Purchases | 60% loan-funded, 40% profit-funded, weighted distributions |
| **FactItems** | ~36,000 | Inventory | 70% Grade 1, 15% top-tier, 20-50% markup, sell-through simulation |
| **FactSales** | ~21,800 | Transactions | 1-50 items/transaction, 3 payment methods, 35% recurring customers |
| **FactExpenses** | ~200 | Operating costs | Rent, Staff, Utilities, Transport, Other |
| **FactCashMovements** | ~1,200 | Cash flow | 3 accounts, daily reconciliation, year-end sweeps |
| **TOTAL** | **~59,600+** | | |

---

## 🎨 Technical Highlights

### 1. Weighted Random Distributions
Implemented realistic business patterns throughout:

```sql
-- Category distribution: Tops 25%, Bottoms 30%, Outerwear 15%, etc.
CASE 
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 25 THEN 1  -- Tops
    WHEN (ABS(CHECKSUM(NEWID())) % 100) < 55 THEN 2  -- Bottoms
    -- ...
END AS CategoryID
```

### 2. Business Rule Enforcement
- **Store Opening:** January 4, 2024 (Thursday) - pre-opening period closed
- **Operating Days:** Closed all Sundays + Christian holidays (Easter, Christmas)
- **Sales Periods:** 3-week windows (Feb 5-25, Jun 3-23, Nov 4-24)
- **Discount Logic:** 25% (90-119 days), 40% (120-179 days), 50% (180+ days old)
- **Item Constraints:** Total items ALWAYS equals sellable + unsellable

### 3. Sell-Through Simulation
Dynamic probability model based on:
- **Fast-moving vs Regular:** 95% vs 75% base probability
- **Seasonal factors:** Q1 (85%), Q2 (105%), Q3 (120%), Q4 (135%)
- **Price sensitivity:** <₦3K (155%), ₦3K-₦6K (130%), >₦6K (110%)
- **Randomization:** 50-100% variation factor

### 4. Financial Reconciliation
Three-account cash flow system:
- **Profits Account:** Sales revenue (starting: ₦250K)
- **Operations Account:** Working capital (starting: ₦100K)
- **Debts Account:** Loan management (starting: ₦0)
- **Daily flows:** 70% sales → Operations, 65% of that → Debts
- **Deficit handling:** Automatic supplementation with 10% buffer
- **Year-end sweeps:** Debts→₦0, Operations≤₦500K, Profits gets remainder

---

## 🚀 Quick Start

### Prerequisites
- SQL Server 2022 (or 2019+)
- SQL Server Management Studio (SSMS)
- Minimum 1GB disk space

### Installation

```bash
# Clone the repository
git clone https://github.com/Elijjjaaaahhhhh/amazing-grace-retail-analytics.git
cd amazing-grace-retail-analytics

# Open SSMS and connect to your SQL Server instance
```

### Execute Scripts in Order

```sql
-- 1. Create database and schema
USE master;
:r database/schema/01_create_database.sql
:r database/schema/02_create_dimensions.sql
:r database/schema/03_create_facts.sql

-- 2. Populate dimension tables
:r database/data/01_populate_dimcategories.sql
:r database/data/02_populate_dimsubcategories.sql
:r database/data/03_populate_dimbellsizes.sql
:r database/data/04_populate_dimitemgrades.sql
:r database/data/05_generate_dimdate.sql

-- 3. Generate fact data (in order - dependencies matter!)
:r database/data/06_generate_factloans.sql
:r database/data/07_generate_factloanrepayments.sql
:r database/data/08_generate_factbells.sql
:r database/data/09_generate_factitems.sql
:r database/data/10_generate_factsales.sql
:r database/data/11_generate_factexpenses.sql
:r database/data/12_generate_factcashmovements.sql

-- 4. Verify data quality
:r database/verification/verify_all.sql
```

### Alternative: Single Execution

```bash
# Windows PowerShell
sqlcmd -S localhost -E -i setup_complete.sql

# Linux/Mac
sqlcmd -S localhost -U sa -P YourPassword -i setup_complete.sql
```

---

## 📁 Repository Structure

```
amazing-grace-retail-analytics/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── setup_complete.sql                 # Single-file execution script
│
├── database/
│   ├── schema/
│   │   ├── 01_create_database.sql    # Database + filegroups
│   │   ├── 02_create_dimensions.sql  # 5 dimension tables
│   │   └── 03_create_facts.sql       # 7 fact tables
│   │
│   ├── data/
│   │   ├── 01-05_populate_dimensions.sql  # Static reference data
│   │   └── 06-12_generate_facts.sql       # Synthetic data generation
│   │
│   └── verification/
│       ├── verify_all.sql            # Complete data quality checks
│       └── sample_queries.sql        # Business intelligence queries
│
├── docs/
│   ├── ARCHITECTURE.md               # Star schema design decisions
│   ├── BUSINESS_RULES.md             # Domain logic documentation
│   ├── AI_COLLABORATION.md           # Claude partnership methodology
│   ├── PROJECT_PHASES.md             # Phase 1, 2, 3 roadmap
│   └── ERD.md                        # Mermaid diagram + text ERD
│
└── assets/
    └── screenshots/                  # Verification results, sample data
```

---

## 🤝 AI Collaboration Methodology

This project showcases effective **human-AI partnership** in data engineering:

### My Role (Ibeh Chidera Elijah)
- ✅ Defined all business requirements and domain knowledge
- ✅ Made architectural decisions (Star schema, table relationships)
- ✅ Debugged constraint violations and data issues
- ✅ Developed custom solutions (MERGE-based ID mapping, deficit handling)
- ✅ Validated data quality and business logic accuracy
- ✅ Owned final code - every script reviewed and understood

### Claude AI's Role
- 💡 Generated boilerplate SQL code and templates
- 💡 Suggested best practices and optimization techniques
- 💡 Provided troubleshooting ideas and alternative approaches
- 💡 Accelerated development through rapid iteration
- 💡 Documented patterns and edge cases

### Key Problem-Solving Examples

**Challenge 1: FactBells Constraint Violations**
- **Issue:** `TotalItems != SellableItems + UnsellableItems` after UPDATE
- **Root Cause:** SQL UPDATE uses OLD column values in same statement
- **Solution:** Split into two sequential UPDATEs
- **Collaboration:** Claude suggested workarounds, I debugged execution order

**Challenge 2: FactSales ID Mapping**
- **Issue:** `OUTPUT` clause couldn't reference source table columns
- **Root Cause:** SQL Server limitation on OUTPUT + source table joins
- **Solution:** Used MERGE with `ON 1=0` to force INSERT while capturing both INSERTED and source columns
- **Collaboration:** Claude proposed MERGE approach, I validated business logic

**Challenge 3: FactCashMovements Negative Balances**
- **Issue:** Accounts ending days with negative balances
- **Root Cause:** Deficit corrections happening AFTER end-of-day calculation
- **Solution:** Immediate in-day corrections with 10% buffer + ₦1,000
- **Collaboration:** I defined business rules, Claude implemented reconciliation logic

📖 **Full collaboration log:** [docs/AI_COLLABORATION.md](docs/AI_COLLABORATION.md)

---

## 🔍 Sample Business Queries

### Monthly Revenue with Sell-Through Rate
```sql
SELECT 
    d.MonthName,
    COUNT(DISTINCT fs.SaleTransactionID) AS Transactions,
    FORMAT(SUM(fs.TotalAmount), 'C', 'en-NG') AS Revenue,
    CAST(
        SUM(CASE WHEN fi.IsSold = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS SellThroughPct
FROM dbo.FactSales fs
JOIN dbo.DimDate d ON fs.SaleDateKey = d.DateKey
JOIN dbo.FactItems fi ON fs.SaleTransactionID = fi.SaleTransactionID
GROUP BY d.Month, d.MonthName
ORDER BY d.Month;
```

### Loan Performance Dashboard
```sql
SELECT 
    l.LoanID,
    FORMAT(l.PrincipalAmount, 'C', 'en-NG') AS Principal,
    l.DurationMonths,
    l.EffectiveInterestRate,
    COUNT(r.RepaymentID) AS PaymentsMade,
    SUM(r.ActualAmount) AS TotalRepaid,
    CASE WHEN l.IsFullyRepaid = 1 THEN 'Closed' ELSE 'Active' END AS Status
FROM dbo.FactLoans l
LEFT JOIN dbo.FactLoanRepayments r ON l.LoanID = r.LoanID
GROUP BY l.LoanID, l.PrincipalAmount, l.DurationMonths, 
         l.EffectiveInterestRate, l.IsFullyRepaid;
```

### Inventory Aging Analysis
```sql
SELECT 
    c.CategoryName,
    COUNT(*) AS TotalItems,
    AVG(fi.DaysInInventory) AS AvgAge,
    SUM(CASE WHEN fi.IsSold = 1 THEN 1 ELSE 0 END) AS SoldItems,
    SUM(CASE WHEN fi.IsInDiscount = 1 THEN 1 ELSE 0 END) AS DiscountedItems
FROM dbo.FactItems fi
JOIN dbo.DimCategories c ON fi.CategoryID = c.CategoryID
GROUP BY c.CategoryName
ORDER BY AVG(fi.DaysInInventory) DESC;
```

More examples: [database/verification/sample_queries.sql](database/verification/sample_queries.sql)

---

## 📈 Next Steps (Phase 3)

### Power BI Dashboard Development
- [ ] **Sales Dashboard:** Daily/weekly/monthly trends, payment method analysis
- [ ] **Inventory Dashboard:** Stock levels, aging analysis, category performance
- [ ] **Financial Dashboard:** Cash flow, loan management, P&L statement
- [ ] **Operational Dashboard:** Bell performance, sell-through rates, discount effectiveness

### Future Enhancements
- [ ] Stored procedures for daily operations
- [ ] Automated data refresh jobs
- [ ] Customer segmentation analysis
- [ ] Predictive analytics for inventory planning

---

## 🛠️ Tools & Technologies

| Category | Technology | Version | Purpose |
|----------|-----------|---------|---------|
| **Database** | SQL Server | 2022 | Data warehouse platform |
| **Development** | SSMS | Latest | Query development & execution |
| **Version Control** | Git + GitHub | - | Source code management |
| **AI Assistant** | Claude (Anthropic) | Sonnet 4.5 | Pair programming & acceleration |
| **Documentation** | Markdown | - | Technical documentation |
| **Visualization** | Mermaid | - | ERD diagrams |

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Ibeh Chidera Elijah**  
📍 Lagos, Nigeria  
🔗 GitHub: [@Elijjjaaaahhhhh](https://github.com/Elijjjaaaahhhhh)

### Skills Demonstrated
- ✅ SQL Server database design & optimization
- ✅ Dimensional modeling (Star schema)
- ✅ Synthetic data generation at scale
- ✅ Complex business logic implementation
- ✅ Data quality assurance & validation
- ✅ AI-augmented development workflow
- ✅ Technical documentation

---

## 🙏 Acknowledgments

- **Claude AI (Anthropic)** - For pair programming partnership and rapid iteration
- **Amazing Grace Store** - For the inspiring business model
- **Lagos Tech Community** - For continuous support and feedback

---

## 📞 Contact & Feedback

Questions? Suggestions? Opportunities?

- 📧 Open an issue on this repository
- 💬 Start a discussion in the Discussions tab
- 🌟 Star this repo if you found it helpful!

---

**Built with ❤️ in Lagos, Nigeria 🇳🇬**
