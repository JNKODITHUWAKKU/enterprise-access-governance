-- ============================================================
-- Gold Layer: Table Creation + Population
-- Enterprise Access Governance & Privilege Analytics Engine
-- ============================================================
-- Fabric Data Warehouse constraints applied:
--   - VARCHAR (not NVARCHAR): Parquet/Delta storage limitation
--   - PRIMARY KEY columns must be NOT NULL
--   - PRIMARY KEY via ALTER TABLE as NONCLUSTERED NOT ENFORCED
--     (metadata hint for query optimizer, not enforced at write)
--   - RowCount is reserved keyword — using RecordCount alias
-- ============================================================


-- ============================================================
-- STEP 0: CLEANUP (safe to re-run)
-- ============================================================
IF OBJECT_ID('dbo.gold_GroupInheritance', 'U') IS NOT NULL DROP TABLE dbo.gold_GroupInheritance;
IF OBJECT_ID('dbo.gold_GroupPermissions', 'U') IS NOT NULL DROP TABLE dbo.gold_GroupPermissions;
IF OBJECT_ID('dbo.gold_GroupMemberships', 'U') IS NOT NULL DROP TABLE dbo.gold_GroupMemberships;
IF OBJECT_ID('dbo.gold_Resources',        'U') IS NOT NULL DROP TABLE dbo.gold_Resources;
IF OBJECT_ID('dbo.gold_Groups',           'U') IS NOT NULL DROP TABLE dbo.gold_Groups;
IF OBJECT_ID('dbo.gold_Users',            'U') IS NOT NULL DROP TABLE dbo.gold_Users;
GO
PRINT 'Cleanup complete';
GO


-- ============================================================
-- STEP 1: CREATE TABLES
-- PK columns declared NOT NULL — required for PRIMARY KEY constraint
-- Non-key columns remain nullable (optional attributes)
-- ============================================================
CREATE TABLE dbo.gold_Users (
    EmployeeId      VARCHAR(100)    NOT NULL,   -- PK
    Name            VARCHAR(200)    NOT NULL,
    Email           VARCHAR(300)    NOT NULL,
    EmployeeType    VARCHAR(50)     NOT NULL,
    DepartmentId    VARCHAR(100),
    HireDate        DATE,
    ManagerId       VARCHAR(100)
);
GO

CREATE TABLE dbo.gold_Groups (
    GroupId         VARCHAR(100)    NOT NULL,   -- PK
    GroupName       VARCHAR(200)    NOT NULL,
    Description     VARCHAR(500)
);
GO

CREATE TABLE dbo.gold_Resources (
    ResourceId          VARCHAR(100)    NOT NULL,   -- PK
    ResourceName        VARCHAR(200)    NOT NULL,
    ResourceType        VARCHAR(100)    NOT NULL,
    Sensitivity         VARCHAR(50)     NOT NULL,
    OwnerDepartmentId   VARCHAR(100)
);
GO

CREATE TABLE dbo.gold_GroupMemberships (
    EmployeeId      VARCHAR(100)    NOT NULL,   -- PK (composite)
    GroupId         VARCHAR(100)    NOT NULL,   -- PK (composite)
    AssignedDate    DATE,
    AssignedBy      VARCHAR(200)
);
GO

CREATE TABLE dbo.gold_GroupPermissions (
    GroupId         VARCHAR(100)    NOT NULL,   -- PK (composite)
    ResourceId      VARCHAR(100)    NOT NULL,   -- PK (composite)
    PermissionLevel VARCHAR(50)     NOT NULL,
    GrantedDate     DATE
);
GO

CREATE TABLE dbo.gold_GroupInheritance (
    ChildGroupId    VARCHAR(100)    NOT NULL,   -- PK (composite)
    ParentGroupId   VARCHAR(100)    NOT NULL,   -- PK (composite)
    InheritanceType VARCHAR(50)
);
GO
PRINT 'All Gold tables created';
GO


-- ============================================================
-- STEP 2: PRIMARY KEY CONSTRAINTS (NONCLUSTERED NOT ENFORCED)
-- Fabric Warehouse requires this exact syntax via ALTER TABLE.
-- These are metadata-only optimizer hints — not enforced at write.
-- Data integrity is guaranteed upstream by Silver layer DQ checks.
-- ============================================================
ALTER TABLE dbo.gold_Users
    ADD CONSTRAINT PK_gold_Users
    PRIMARY KEY NONCLUSTERED (EmployeeId) NOT ENFORCED;
GO

ALTER TABLE dbo.gold_Groups
    ADD CONSTRAINT PK_gold_Groups
    PRIMARY KEY NONCLUSTERED (GroupId) NOT ENFORCED;
GO

ALTER TABLE dbo.gold_Resources
    ADD CONSTRAINT PK_gold_Resources
    PRIMARY KEY NONCLUSTERED (ResourceId) NOT ENFORCED;
GO

ALTER TABLE dbo.gold_GroupMemberships
    ADD CONSTRAINT PK_gold_GroupMemberships
    PRIMARY KEY NONCLUSTERED (EmployeeId, GroupId) NOT ENFORCED;
GO

ALTER TABLE dbo.gold_GroupPermissions
    ADD CONSTRAINT PK_gold_GroupPermissions
    PRIMARY KEY NONCLUSTERED (GroupId, ResourceId) NOT ENFORCED;
GO

ALTER TABLE dbo.gold_GroupInheritance
    ADD CONSTRAINT PK_gold_GroupInheritance
    PRIMARY KEY NONCLUSTERED (ChildGroupId, ParentGroupId) NOT ENFORCED;
GO
PRINT 'PRIMARY KEY NONCLUSTERED NOT ENFORCED constraints added';
GO


-- ============================================================
-- STEP 3: POPULATE gold_Users
-- ============================================================
INSERT INTO dbo.gold_Users
    (EmployeeId, Name, Email, EmployeeType, DepartmentId, HireDate, ManagerId)
SELECT
    employee_id,
    name,
    email,
    employee_type,
    department_id,
    TRY_CAST(hire_date AS DATE),
    manager_id
FROM access_governance_lakehouse.dbo.silver_employees;
GO
PRINT 'gold_Users populated';
GO


-- ============================================================
-- STEP 4: POPULATE gold_Groups
-- ============================================================
INSERT INTO dbo.gold_Groups (GroupId, GroupName, Description)
SELECT group_id, group_name, description
FROM access_governance_lakehouse.dbo.silver_security_groups;
GO
PRINT 'gold_Groups populated';
GO


-- ============================================================
-- STEP 5: POPULATE gold_Resources
-- ============================================================
INSERT INTO dbo.gold_Resources
    (ResourceId, ResourceName, ResourceType, Sensitivity, OwnerDepartmentId)
SELECT resource_id, resource_name, resource_type, sensitivity, owner_department_id
FROM access_governance_lakehouse.dbo.silver_resources;
GO
PRINT 'gold_Resources populated';
GO


-- ============================================================
-- STEP 6: POPULATE gold_GroupMemberships
-- ============================================================
INSERT INTO dbo.gold_GroupMemberships (EmployeeId, GroupId, AssignedDate, AssignedBy)
SELECT
    employee_id,
    group_id,
    TRY_CAST(assigned_date AS DATE),
    assigned_by
FROM access_governance_lakehouse.dbo.silver_group_memberships;
GO
PRINT 'gold_GroupMemberships populated';
GO


-- ============================================================
-- STEP 7: POPULATE gold_GroupPermissions
-- ============================================================
INSERT INTO dbo.gold_GroupPermissions (GroupId, ResourceId, PermissionLevel, GrantedDate)
SELECT
    group_id,
    resource_id,
    permission_level,
    TRY_CAST(granted_date AS DATE)
FROM access_governance_lakehouse.dbo.silver_group_permissions;
GO
PRINT 'gold_GroupPermissions populated';
GO


-- ============================================================
-- STEP 8: POPULATE gold_GroupInheritance
-- ============================================================
INSERT INTO dbo.gold_GroupInheritance (ChildGroupId, ParentGroupId, InheritanceType)
SELECT child_group_id, parent_group_id, 'Full'
FROM access_governance_lakehouse.dbo.silver_group_inheritance;
GO
PRINT 'gold_GroupInheritance populated';
GO


-- ============================================================
-- FINAL SUMMARY
-- ============================================================
PRINT '============================================================';
PRINT 'GOLD LAYER COMPLETE';
PRINT '============================================================';
SELECT 'gold_Users'             AS TableName, COUNT(*) AS RecordCount FROM dbo.gold_Users           UNION ALL
SELECT 'gold_Groups',                         COUNT(*)               FROM dbo.gold_Groups           UNION ALL
SELECT 'gold_Resources',                      COUNT(*)               FROM dbo.gold_Resources        UNION ALL
SELECT 'gold_GroupMemberships',               COUNT(*)               FROM dbo.gold_GroupMemberships UNION ALL
SELECT 'gold_GroupPermissions',               COUNT(*)               FROM dbo.gold_GroupPermissions UNION ALL
SELECT 'gold_GroupInheritance',               COUNT(*)               FROM dbo.gold_GroupInheritance;
GO
