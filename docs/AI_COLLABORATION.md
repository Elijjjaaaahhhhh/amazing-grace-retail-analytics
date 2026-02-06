# AI Collaboration Methodology

## Overview

This project demonstrates effective **human-AI partnership** in professional data engineering. Rather than using AI as a replacement for expertise, I (Ibeh Chidera Elijah) leveraged Claude as a **pair programmer** to accelerate development while maintaining complete ownership of design decisions and code quality.

---

## Partnership Framework

### My Responsibilities
✅ **Domain expertise** - Defined all business requirements based on retail operations knowledge  
✅ **Architecture decisions** - Chose Star Schema, determined table relationships and grain  
✅ **Quality assurance** - Validated all generated data against business rules  
✅ **Debugging** - Diagnosed constraint violations and logic errors  
✅ **Final approval** - Reviewed and understood every line of code before execution  
✅ **Innovation** - Developed custom solutions when AI suggestions didn't fit

### Claude AI's Contributions
💡 **Code generation** - Produced boilerplate SQL scripts and templates  
💡 **Best practices** - Suggested indexing strategies and performance optimizations  
💡 **Documentation** - Generated comprehensive inline comments and README content  
💡 **Troubleshooting** - Proposed alternative approaches when issues arose  
💡 **Acceleration** - Enabled rapid iteration through conversation-driven development

---

## Key Problem-Solving Case Studies

### 1. FactBells: Constraint Violation (`TotalItems != SellableItems + UnsellableItems`)

**Context:** After inserting bells with placeholder values, the UPDATE statements to calculate final values violated the CHECK constraint.

**The Problem:**
```sql
-- Original approach (FAILED)
UPDATE dbo.FactBells
SET SellableItems = CAST(TotalItems * SellablePercentage AS INT),
    UnsellableItems = TotalItems - SellableItems;  -- Uses OLD value!
```

**Root Cause:** SQL Server UPDATE statements reference the **pre-update** value of columns in the same statement, not the newly calculated value.

**My Solution:**
```sql
-- Split into two sequential UPDATEs
UPDATE dbo.FactBells
SET SellableItems = CAST(TotalItems * SellablePercentage AS INT);

UPDATE dbo.FactBells
SET UnsellableItems = TotalItems - SellableItems;  -- Now uses NEW value
```

**AI's Role:** Claude initially suggested workarounds with CTEs and temp tables, but I identified the simpler execution-order fix.

**Outcome:** ✅ Constraint satisfied, no temporary tables needed, cleaner code

---

### 2. FactSales: ID Mapping with OUTPUT Clause

**Context:** After inserting sales transactions with auto-increment IDs, needed to link items back to their transaction using the generated IDs.

**The Problem:**
```sql
-- Standard OUTPUT approach (FAILED)
INSERT INTO FactSales (...)
OUTPUT INSERTED.SaleTransactionID, source_table.RowNum  -- Can't reference source!
INTO @Mapping
SELECT ... FROM #TempSales AS source_table;
```

**Root Cause:** SQL Server's OUTPUT clause cannot reference columns from the source table in a standard INSERT statement.

**My Solution (inspired by Claude's suggestion):**
```sql
-- Use MERGE with impossible condition to force INSERT
MERGE dbo.FactSales AS tgt
USING (
    SELECT *, ROW_NUMBER() OVER (ORDER BY TempID) AS RowNum
    FROM #TempSales
) AS src
ON 1 = 0  -- Never matches - forces INSERT for all rows
WHEN NOT MATCHED THEN
    INSERT (SaleDateKey, SaleDateTime, ...)
    VALUES (src.SaleDateKey, src.SaleDateTime, ...)
OUTPUT 
    INSERTED.SaleTransactionID,
    src.RowNum  -- ✅ Can reference source in MERGE!
INTO @Mapping;
```

**AI's Role:** Claude proposed the MERGE approach; I validated it against business logic and tested edge cases.

**Outcome:** ✅ Perfect ID mapping, all 21,800+ transactions linked correctly to their items

---

### 3. FactCashMovements: Negative Account Balances

**Context:** Three-account cash flow system (Profits, Operations, Debts) was ending days with negative balances despite deficit correction logic.

**The Problem:**
```
Dec 31 Final Balances:
- Debts: ₦0 ✓
- Operations: -₦18,730,138.79 ✗  (SHOULD BE 0-500K)
- Profits: ₦78,506,449.15 ✓
```

**Root Cause:** Deficit corrections were only checked at END of day processing, but additional transactions (like year-end sweeps) happened afterward without rechecking.

**Business Rules (I defined):**
- **Daily rule:** No account should EVER end a day negative
- **Correction logic:** If negative detected:
  - Debts negative → Operations supplements (amount + 10% + ₦1,000)
  - Operations negative → Profits supplements (amount + 10% + ₦1,000)
- **Year-end sweeps:**
  - Debts → ₦0 (all to Profits)
  - Operations → ₦0-₦500K (excess to Profits)
  - Profits → receives remainder

**My Solution (implemented with Claude's code generation):**
```sql
-- Process each day with in-loop deficit checks
WHILE @CurrentDate <= @YearEnd
BEGIN
    -- 1. Process all movements for the day
    -- 2. Check Debts balance
    IF @DebtsBalance < 0
        INSERT correction: Operations → Debts
    
    -- 3. Check Operations balance (after possible Debts correction)
    IF @OperationsBalance < 0
        INSERT correction: Profits → Operations
    
    -- 4. Move to next day (balances now guaranteed positive)
END
```

**AI's Role:** Claude generated the procedural loop structure; I defined the exact correction amounts and buffer logic.

**Outcome:** ✅ Zero negative balances across all 366 days, year-end targets met exactly

---

### 4. DimDate: Business Calendar with Complex Rules

**Context:** Store has unique operating schedule requiring precise date logic.

**Business Rules (I provided):**
- ✅ Store opens January 4, 2024 (Thursday) - Jan 1-3 closed for setup
- ✅ Closed every Sunday
- ✅ Closed Christian holidays:
  - Good Friday (March 29, 2024)
  - Easter Monday (April 1, 2024)
  - Christmas period (December 25-27, 2024)
- ✅ Peak periods: End of month (payday), university resumption, summer holidays
- ✅ Sales periods: 3-week windows (Feb 5-25, Jun 3-23, Nov 4-24)

**My Approach:**
```sql
-- IsStoreOpen: Nested CASE with hierarchical exclusions
CASE 
    WHEN DATENAME(WEEKDAY, FullDate) = 'Sunday' THEN 0
    WHEN FullDate < '2024-01-04' THEN 0
    WHEN FullDate = '2024-03-29' THEN 0  -- Good Friday
    WHEN FullDate = '2024-04-01' THEN 0  -- Easter Monday
    WHEN FullDate BETWEEN '2024-12-25' AND '2024-12-27' THEN 0
    ELSE 1
END AS IsStoreOpen
```

**AI's Role:** Claude generated the recursive CTE for date generation and initial CASE structure; I added all business-specific logic.

**Outcome:** ✅ 306 operating days correctly flagged, all constraints validated

---

### 5. FactItems: Sell-Through Probability Simulation

**Context:** Needed realistic sell-through rates varying by item characteristics.

**My Probability Model (I designed):**
```sql
SellProbability = FastMovingFactor × SeasonalFactor × PriceFactor × RandomFactor

WHERE:
  FastMovingFactor = 95% (fast-moving) OR 75% (regular)
  
  SeasonalFactor = 
    Q1: 85%  (post-holiday slow)
    Q2: 105% (spring moderate)
    Q3: 120% (back-to-school peak)
    Q4: 135% (holiday peak)
  
  PriceFactor =
    <₦3K:     155% (high demand)
    ₦3K-₦6K:  130% (moderate)
    >₦6K:     110% (luxury)
  
  RandomFactor = 50-100% (variation)
  
Item SOLD if: SellProbability > 60%
```

**AI's Role:** Claude implemented the CTE structure and CASE logic; I tuned the percentages through multiple iterations.

**Outcome:** ✅ Realistic 60-75% overall sell-through, higher for fast-moving items, seasonal patterns visible

---

## Workflow Pattern

### Typical Development Cycle

```
1. I DEFINE requirement
   ↓
2. Claude GENERATES initial code
   ↓
3. I EXECUTE and TEST
   ↓
4. Issue discovered?
   ├─ YES → I DIAGNOSE root cause → Back to step 2 with clarification
   └─ NO → I VALIDATE business logic → APPROVED ✓
```

### Example: FactBells Generation

**Iteration 1:** Claude generated placeholders  
**Issue:** Values stagnant after INSERT  
**My Diagnosis:** Calculations need to happen in temp table BEFORE insert  

**Iteration 2:** Claude modified to calculate in temp table  
**Issue:** Weighted distributions not working (all Category 1)  
**My Diagnosis:** Missing randomization in category assignment  

**Iteration 3:** I provided exact CASE statement for weighted logic  
**Result:** ✅ Correct distribution (Tops 25%, Bottoms 30%, etc.)

---

## Decision-Making Examples

### When I Made the Call

**Architecture:** 
- ❌ Claude suggested Snowflake schema
- ✅ I chose Star schema (query performance priority)

**Data Volume:**
- ❌ Claude proposed 1,000 items/month
- ✅ I calculated realistic 3,000 items/month (36K annual)

**Constraint Logic:**
- ❌ Claude suggested soft validation (queries)
- ✅ I insisted on hard CHECK constraints (database-level enforcement)

**Loan Terms:**
- ❌ Claude used generic 10-15% interest
- ✅ I researched Lagos microfinance rates: 12-18% realistic

### When Claude Added Value

**Performance:**
- 💡 Suggested filtered indexes on bit columns (WHERE column = 1)
- 💡 Recommended NONCLUSTERED indexes on all foreign keys
- ✅ I validated index overhead vs query benefit, approved selectively

**Code Quality:**
- 💡 Proposed using CTEs instead of cursors where possible
- 💡 Recommended MERGE over INSERT+UPDATE for atomicity
- ✅ I evaluated trade-offs, adopted when appropriate

**Documentation:**
- 💡 Generated comprehensive inline comments
- 💡 Suggested Mermaid diagrams for ERD visualization
- ✅ I reviewed for accuracy, approved with minor edits

---

## Tools & Communication

### Prompting Strategies I Used

**1. Constraint-First Development**
```
"Generate the table DDL with these CHECK constraints:
- TotalItems MUST equal SellableItems + UnsellableItems
- BellCost BETWEEN ₦350,000 AND ₦850,000
- ...
Do NOT generate data yet, just schema."
```

**2. Business Rule Documentation**
```
"Here are the exact sales period rules:
- February: Days 5-25 (3 weeks)
- June: Days 3-23 (3 weeks)
- November: Days 4-24 (3 weeks)
Generate the CASE statement for IsSalesPeriod."
```

**3. Debugging with Context**
```
"The constraint violation shows:
[Error message]

The table definition has:
[DDL snippet]

The failing UPDATE is:
[SQL snippet]

Explain why this fails, then provide a fix."
```

### Verification Pattern

After EVERY generated script:
1. ✅ I read the entire code
2. ✅ I checked against business rules
3. ✅ I executed with sample data
4. ✅ I ran validation queries
5. ✅ Only then moved to next step

---

## Lessons Learned

### What Worked Well

✅ **Clear requirements** → High-quality first drafts  
✅ **Incremental iteration** → Easy debugging  
✅ **Explicit constraints** → Fewer logic errors  
✅ **Business context** → Realistic data patterns  

### What Didn't Work

❌ **Vague prompts** → Generic, unusable code  
❌ **Skipping validation** → Cascading errors  
❌ **Blind trust** → Hidden bugs in edge cases  
❌ **Too much at once** → Hard to isolate issues  

### My Key Insights

1. **AI accelerates execution, not thinking** - I still had to understand every concept deeply
2. **Domain knowledge is irreplaceable** - Claude doesn't know Lagos retail without me teaching it
3. **Debugging is collaborative** - Claude suggests ideas, I validate with business logic
4. **Code ownership matters** - I can explain and defend every design decision

---

## Metrics

### Time Investment
- **Phase 1 (Schema):** ~4 hours (with AI) vs estimated 8-12 hours (solo)
- **Phase 2 (Data):** ~12 hours (with AI) vs estimated 30-40 hours (solo)
- **Total savings:** ~60% time reduction
- **Quality:** Same or better (more comprehensive testing due to faster iteration)

### Lines of Code
- **Generated by AI:** ~8,000 lines (80% of boilerplate)
- **Modified by me:** ~2,000 lines (20% business logic refinement)
- **Final production code:** ~10,000 lines fully understood and owned

---

## Recommendations for AI-Augmented Development

### Do This ✅
1. Start with clear, detailed requirements
2. Generate schema before data
3. Test incrementally (table by table)
4. Validate every output against business rules
5. Document your decisions, not just AI's suggestions
6. Maintain code ownership - understand everything

### Avoid This ❌
1. Don't blindly execute generated code
2. Don't skip constraint validation
3. Don't assume AI knows your domain
4. Don't merge debugging into generation (isolate problems)
5. Don't let AI make architecture decisions alone
6. Don't sacrifice learning for speed

---

## Conclusion

This project demonstrates that AI is most powerful as a **force multiplier for existing expertise**, not a replacement for it. I used Claude to:

- ⚡ Move faster on routine tasks
- 🤔 Explore alternative approaches quickly
- 📝 Generate comprehensive documentation
- 🐛 Debug complex issues collaboratively

But I maintained:

- 🧠 Complete understanding of all code
- 🎯 Final decision authority on all design choices
- ✅ Quality assurance through validation
- 💼 Ownership of business requirements

**Result:** A production-grade data warehouse built in 60% less time without compromising quality or learning.

---

**Author:** Ibeh Chidera Elijah  
**AI Partner:** Claude (Anthropic) - Sonnet 4.5  
**Project:** Amazing Grace Store Data Warehouse  
**Date:** February 2026
