USE master;
GO

-- Drop database if exists (USE WITH CAUTION IN PRODUCTION)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'AmazingGraceStore')
BEGIN
    ALTER DATABASE AmazingGraceStore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE AmazingGraceStore;
END
GO

-- Create new database
CREATE DATABASE AmazingGraceStore
ON PRIMARY
(
    NAME = N'AmazingGraceStore_Data',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\AmazingGraceStore.mdf',
    SIZE = 512MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 128MB
)
LOG ON
(
    NAME = N'AmazingGraceStore_Log',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\AmazingGraceStore_log.ldf',
    SIZE = 256MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 64MB
);
GO

-- Set database options
ALTER DATABASE AmazingGraceStore SET RECOVERY SIMPLE;
ALTER DATABASE AmazingGraceStore SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE AmazingGraceStore SET AUTO_UPDATE_STATISTICS ON;
GO

-- Use the new database
USE AmazingGraceStore;
GO

PRINT 'Database AmazingGraceStore created successfully!';
GO