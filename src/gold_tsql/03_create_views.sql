-- ============================================================
-- Gold Layer: VIEWS for Power BI Direct Lake Consumption
-- Enterprise Access Governance & Privilege Analytics Engine
-- ============================================================
-- Views implement graph traversal using standard JOINs on
-- Gold relational tables — fully supported on Fabric Warehouse.
-- Run AFTER create_nodes_edges.sql has been executed successfully.
-- ============================================================


-- ============================================================
-- VIEW 1: vw_ToxicAccessPaths
-- Full union of direct + inherited toxic paths.
-- Primary view consumed by Power BI and Data Activator.
-- ============================================================
IF OBJECT_ID('dbo.vw_ToxicAccessPaths', 'V') IS NOT NULL DROP VIEW dbo.vw_ToxicAccessPaths;
GO

CREATE VIEW dbo.vw_ToxicAccessPaths AS

    -- Direct paths (1-hop: User -> Group -> Resource)
    SELECT
        u.EmployeeId                    AS ContractorId,
        u.Name                          AS ContractorName,
        u.Email                         AS ContractorEmail,
        u.EmployeeType,
        g.GroupName                     AS DirectGroup,
        CAST(NULL AS VARCHAR(200))      AS InheritedGroup,
        r.ResourceId,
        r.ResourceName,
        r.ResourceType,
        r.Sensitivity,
        gp.PermissionLevel,
        'Direct'                        AS PathType,
        CONCAT(
            u.Name, ' -> ', g.GroupName,
            ' -> [', gp.PermissionLevel, '] ',
            r.ResourceName, ' (', r.Sensitivity, ')'
        )                               AS AccessPath,
        'Open'                          AS RemediationStatus
    FROM
        dbo.gold_Users              u
        INNER JOIN dbo.gold_GroupMemberships   gm  ON gm.EmployeeId  = u.EmployeeId
        INNER JOIN dbo.gold_Groups             g   ON g.GroupId      = gm.GroupId
        INNER JOIN dbo.gold_GroupPermissions   gp  ON gp.GroupId     = g.GroupId
        INNER JOIN dbo.gold_Resources          r   ON r.ResourceId   = gp.ResourceId
    WHERE
        u.EmployeeType      IN ('Contractor', 'Vendor')
        AND r.Sensitivity   IN ('High', 'Critical')
        AND gp.PermissionLevel IN ('Write', 'Admin')

    UNION ALL

    -- Inherited paths (2-hop: User -> GroupA -> GroupB -> Resource)
    SELECT
        u.EmployeeId,
        u.Name,
        u.Email,
        u.EmployeeType,
        g1.GroupName                    AS DirectGroup,
        g2.GroupName                    AS InheritedGroup,
        r.ResourceId,
        r.ResourceName,
        r.ResourceType,
        r.Sensitivity,
        gp.PermissionLevel,
        'Inherited'                     AS PathType,
        CONCAT(
            u.Name, ' -> ', g1.GroupName,
            ' -> (inherits) ', g2.GroupName,
            ' -> [', gp.PermissionLevel, '] ',
            r.ResourceName, ' (', r.Sensitivity, ')'
        )                               AS AccessPath,
        'Open'                          AS RemediationStatus
    FROM
        dbo.gold_Users              u
        INNER JOIN dbo.gold_GroupMemberships   gm   ON gm.EmployeeId   = u.EmployeeId
        INNER JOIN dbo.gold_Groups             g1   ON g1.GroupId      = gm.GroupId
        INNER JOIN dbo.gold_GroupInheritance   gi   ON gi.ChildGroupId = g1.GroupId
        INNER JOIN dbo.gold_Groups             g2   ON g2.GroupId      = gi.ParentGroupId
        INNER JOIN dbo.gold_GroupPermissions   gp   ON gp.GroupId      = g2.GroupId
        INNER JOIN dbo.gold_Resources          r    ON r.ResourceId    = gp.ResourceId
    WHERE
        u.EmployeeType      IN ('Contractor', 'Vendor')
        AND r.Sensitivity   IN ('High', 'Critical')
        AND gp.PermissionLevel IN ('Write', 'Admin');
GO

PRINT 'Created view: vw_ToxicAccessPaths';
GO


-- ============================================================
-- VIEW 2: vw_RiskSummary (KPI cards for Power BI)
-- ============================================================
IF OBJECT_ID('dbo.vw_RiskSummary', 'V') IS NOT NULL DROP VIEW dbo.vw_RiskSummary;
GO

CREATE VIEW dbo.vw_RiskSummary AS
SELECT
    COUNT(*)                                                        AS TotalToxicPaths,
    COUNT(DISTINCT ContractorId)                                    AS AffectedContractors,
    COUNT(DISTINCT ResourceId)                                      AS ExposedResources,
    SUM(CASE WHEN Sensitivity     = 'Critical'  THEN 1 ELSE 0 END) AS CriticalPaths,
    SUM(CASE WHEN Sensitivity     = 'High'      THEN 1 ELSE 0 END) AS HighPaths,
    SUM(CASE WHEN PermissionLevel = 'Admin'     THEN 1 ELSE 0 END) AS AdminPaths,
    SUM(CASE WHEN PermissionLevel = 'Write'     THEN 1 ELSE 0 END) AS WritePaths,
    SUM(CASE WHEN PathType        = 'Inherited' THEN 1 ELSE 0 END) AS InheritedPaths,
    SUM(CASE WHEN PathType        = 'Direct'    THEN 1 ELSE 0 END) AS DirectPaths
FROM dbo.vw_ToxicAccessPaths;
GO

PRINT 'Created view: vw_RiskSummary';
GO


-- ============================================================
-- VIEW 3: vw_ResourceRiskHeatmap (heatmap visual in Power BI)
-- ============================================================
IF OBJECT_ID('dbo.vw_ResourceRiskHeatmap', 'V') IS NOT NULL DROP VIEW dbo.vw_ResourceRiskHeatmap;
GO

CREATE VIEW dbo.vw_ResourceRiskHeatmap AS
SELECT
    ResourceName,
    ResourceType,
    Sensitivity,
    PermissionLevel,
    PathType,
    COUNT(*)                        AS ToxicPathCount,
    COUNT(DISTINCT ContractorId)    AS UniqueContractors
FROM dbo.vw_ToxicAccessPaths
GROUP BY
    ResourceName,
    ResourceType,
    Sensitivity,
    PermissionLevel,
    PathType;
GO

PRINT 'Created view: vw_ResourceRiskHeatmap';
GO


-- ============================================================
-- VIEW 4: vw_AllUsers (org hierarchy + flagged status)
-- ============================================================
IF OBJECT_ID('dbo.vw_AllUsers', 'V') IS NOT NULL DROP VIEW dbo.vw_AllUsers;
GO

CREATE VIEW dbo.vw_AllUsers AS
SELECT
    u.EmployeeId,
    u.Name,
    u.Email,
    u.EmployeeType,
    u.DepartmentId,
    u.HireDate,
    u.ManagerId,
    CASE
        WHEN u.EmployeeId IN (SELECT ContractorId FROM dbo.vw_ToxicAccessPaths)
        THEN 1 ELSE 0
    END AS IsFlagged
FROM dbo.gold_Users u;
GO

PRINT 'Created view: vw_AllUsers';
GO


-- ============================================================
-- VIEW 5: vw_AllResources (resource risk counts)
-- ============================================================
IF OBJECT_ID('dbo.vw_AllResources', 'V') IS NOT NULL DROP VIEW dbo.vw_AllResources;
GO

CREATE VIEW dbo.vw_AllResources AS
SELECT
    r.ResourceId,
    r.ResourceName,
    r.ResourceType,
    r.Sensitivity,
    r.OwnerDepartmentId,
    ISNULL(h.ToxicPathCount,    0) AS ToxicPathCount,
    ISNULL(h.UniqueContractors, 0) AS ExposedContractorCount
FROM
    dbo.gold_Resources r
LEFT JOIN (
    SELECT
        ResourceId,
        COUNT(*)                    AS ToxicPathCount,
        COUNT(DISTINCT ContractorId) AS UniqueContractors
    FROM dbo.vw_ToxicAccessPaths
    GROUP BY ResourceId
) h ON h.ResourceId = r.ResourceId;
GO

PRINT 'Created view: vw_AllResources';
GO


-- ============================================================
-- FINAL VALIDATION
-- ============================================================
PRINT '============================================================';
PRINT 'GOLD VIEWS — VALIDATION';
PRINT '============================================================';

SELECT 'vw_ToxicAccessPaths'   AS ViewName, COUNT(*) AS RecordCount FROM dbo.vw_ToxicAccessPaths  UNION ALL
SELECT 'vw_RiskSummary',                    COUNT(*)              FROM dbo.vw_RiskSummary         UNION ALL
SELECT 'vw_ResourceRiskHeatmap',            COUNT(*)              FROM dbo.vw_ResourceRiskHeatmap  UNION ALL
SELECT 'vw_AllUsers',                       COUNT(*)              FROM dbo.vw_AllUsers             UNION ALL
SELECT 'vw_AllResources',                   COUNT(*)              FROM dbo.vw_AllResources;
GO
