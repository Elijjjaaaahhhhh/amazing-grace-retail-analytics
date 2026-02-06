USE AmazingGraceStore;
GO

CREATE TABLE dbo.DimCategories
(
    CategoryID          INT             NOT NULL IDENTITY(1,1),
    CategoryName        NVARCHAR(50)    NOT NULL,
    CategoryDescription NVARCHAR(200)   NULL,
    
    -- Constraints
    CONSTRAINT PK_DimCategories PRIMARY KEY CLUSTERED (CategoryID),
    CONSTRAINT UQ_DimCategories_Name UNIQUE (CategoryName)
);
GO

-- Create index for lookups
CREATE NONCLUSTERED INDEX IX_DimCategories_Name 
    ON dbo.DimCategories(CategoryName);
GO

PRINT 'Table DimCategories created successfully!';
GO

CREATE TABLE dbo.DimSubcategories
(
    SubcategoryID   INT             NOT NULL IDENTITY(1,1),
    CategoryID      INT             NOT NULL,
    SubcategoryName NVARCHAR(100)   NOT NULL,
    IsFastMoving    BIT             NOT NULL DEFAULT(0),
    
    -- Constraints
    CONSTRAINT PK_DimSubcategories PRIMARY KEY CLUSTERED (SubcategoryID),
    CONSTRAINT FK_DimSubcategories_Category 
        FOREIGN KEY (CategoryID) REFERENCES dbo.DimCategories(CategoryID),
    CONSTRAINT UQ_DimSubcategories_Name 
        UNIQUE (CategoryID, SubcategoryName)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_DimSubcategories_CategoryID 
    ON dbo.DimSubcategories(CategoryID);

CREATE NONCLUSTERED INDEX IX_DimSubcategories_FastMoving 
    ON dbo.DimSubcategories(IsFastMoving) 
    WHERE IsFastMoving = 1;
GO

PRINT 'Table DimSubcategories created successfully!';
GO

CREATE TABLE dbo.DimBellSizes
(
    BellSizeID   INT            NOT NULL IDENTITY(1,1),
    BellSizeName NVARCHAR(20)   NOT NULL,
    MinItems     INT            NOT NULL,
    MaxItems     INT            NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_DimBellSizes PRIMARY KEY CLUSTERED (BellSizeID),
    CONSTRAINT UQ_DimBellSizes_Name UNIQUE (BellSizeName),
    CONSTRAINT CK_DimBellSizes_ItemRange CHECK (MaxItems > MinItems),
    CONSTRAINT CK_DimBellSizes_MinItems CHECK (MinItems > 0)
);
GO

PRINT 'Table DimBellSizes created successfully!';
GO


CREATE TABLE dbo.DimItemGrades
(
    GradeID      INT            NOT NULL,
    GradeName    NVARCHAR(20)   NOT NULL,
    CanBeTopTier BIT            NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_DimItemGrades PRIMARY KEY CLUSTERED (GradeID),
    CONSTRAINT CK_DimItemGrades_ValidGrades CHECK (GradeID IN (1, 2))
);
GO

PRINT 'Table DimItemGrades created successfully!';
GO

CREATE TABLE dbo.DimDate
(
    DateKey        INT           NOT NULL,
    FullDate       DATE          NOT NULL,
    Year           INT           NOT NULL,
    Month          INT           NOT NULL,
    MonthName      NVARCHAR(20)  NOT NULL,
    Quarter        INT           NOT NULL,
    WeekOfYear     INT           NOT NULL,
    DayOfWeek      INT           NOT NULL,
    DayName        NVARCHAR(20)  NOT NULL,
    IsWeekend      BIT           NOT NULL,
    IsStoreOpen    BIT           NOT NULL,
    IsPeakPeriod   BIT           NOT NULL,
    IsSalesPeriod  BIT           NOT NULL,
    FiscalYear     INT           NOT NULL,
    FiscalMonth    INT           NOT NULL,
    
    -- Constraints
    CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (DateKey),
    CONSTRAINT UQ_DimDate_FullDate UNIQUE (FullDate),
    CONSTRAINT CK_DimDate_DateKey CHECK (DateKey >= 20000101 AND DateKey <= 99991231),
    CONSTRAINT CK_DimDate_Month CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT CK_DimDate_Quarter CHECK (Quarter BETWEEN 1 AND 4),
    CONSTRAINT CK_DimDate_DayOfWeek CHECK (DayOfWeek BETWEEN 1 AND 7)
);
GO

-- Create indexes for common queries
CREATE NONCLUSTERED INDEX IX_DimDate_FullDate 
    ON dbo.DimDate(FullDate);

CREATE NONCLUSTERED INDEX IX_DimDate_YearMonth 
    ON dbo.DimDate(Year, Month);

CREATE NONCLUSTERED INDEX IX_DimDate_StoreOpen 
    ON dbo.DimDate(IsStoreOpen) 
    WHERE IsStoreOpen = 1;
GO

PRINT 'Table DimDate created successfully!';
GO