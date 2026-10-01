-- ============================================================
-- Create Stored Procedure: usp_UpsertGoldLayer
-- Enterprise Access Governance & Privilege Analytics Engine
-- ============================================================
-- Called by: Fabric Data Pipeline → Script activity
-- Command  : EXEC dbo.usp_UpsertGoldLayer
-- Purpose  : Incrementally upserts all 6 Gold tables from
--            Silver layer using MERGE (idempotent, safe to
--            run multiple times)
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.usp_UpsertGoldLayer
AS
BEGIN
    SET NOCOUNT ON;

    -- --------------------------------------------------------
    -- MERGE 1: gold_Users ← silver_employees
    -- --------------------------------------------------------
    MERGE INTO dbo.gold_Users AS target
    USING (
        SELECT
            employee_id,
            name,
            email,
            employee_type,
            department_id,
            TRY_CAST(hire_date AS DATE) AS hire_date,
            manager_id
        FROM access_governance_lakehouse.dbo.silver_employees
    ) AS source
    ON target.EmployeeId = source.employee_id

    WHEN MATCHED AND (
        target.Name         <> source.name          OR
        target.Email        <> source.email         OR
        target.EmployeeType <> source.employee_type OR
        ISNULL(target.DepartmentId,'') <> ISNULL(source.department_id,'') OR
        ISNULL(target.ManagerId,'')    <> ISNULL(source.manager_id,'')
    ) THEN UPDATE SET
        target.Name         = source.name,
        target.Email        = source.email,
        target.EmployeeType = source.employee_type,
        target.DepartmentId = source.department_id,
        target.HireDate     = source.hire_date,
        target.ManagerId    = source.manager_id

    WHEN NOT MATCHED BY TARGET THEN INSERT
        (EmployeeId, Name, Email, EmployeeType, DepartmentId, HireDate, ManagerId)
    VALUES
        (source.employee_id, source.name, source.email,
         source.employee_type, source.department_id,
         source.hire_date, source.manager_id);

    -- --------------------------------------------------------
    -- MERGE 2: gold_Groups ← silver_security_groups
    -- --------------------------------------------------------
    MERGE INTO dbo.gold_Groups AS target
    USING (
        SELECT group_id, group_name, description
        FROM access_governance_lakehouse.dbo.silver_security_groups
    ) AS source
    ON target.GroupId = source.group_id

    WHEN MATCHED AND (
        target.GroupName <> source.group_name OR
        ISNULL(target.Description,'') <> ISNULL(source.description,'')
    ) THEN UPDATE SET
        target.GroupName   = source.group_name,
        target.Description = source.description

    WHEN NOT MATCHED BY TARGET THEN INSERT
        (GroupId, GroupName, Description)
    VALUES
        (source.group_id, source.group_name, source.description);

    -- --------------------------------------------------------
    -- MERGE 3: gold_Resources ← silver_resources
    -- --------------------------------------------------------
    MERGE INTO dbo.gold_Resources AS target
    USING (
        SELECT resource_id, resource_name, resource_type, sensitivity, owner_department_id
        FROM access_governance_lakehouse.dbo.silver_resources
    ) AS source
    ON target.ResourceId = source.resource_id

    WHEN MATCHED AND (
        target.ResourceName <> source.resource_name OR
        target.ResourceType <> source.resource_type OR
        target.Sensitivity  <> source.sensitivity   OR
        ISNULL(target.OwnerDepartmentId,'') <> ISNULL(source.owner_department_id,'')
    ) THEN UPDATE SET
        target.ResourceName      = source.resource_name,
        target.ResourceType      = source.resource_type,
        target.Sensitivity       = source.sensitivity,
        target.OwnerDepartmentId = source.owner_department_id

    WHEN NOT MATCHED BY TARGET THEN INSERT
        (ResourceId, ResourceName, ResourceType, Sensitivity, OwnerDepartmentId)
    VALUES
        (source.resource_id, source.resource_name, source.resource_type,
         source.sensitivity, source.owner_department_id);

    -- --------------------------------------------------------
    -- MERGE 4: gold_GroupMemberships ← silver_group_memberships
    -- --------------------------------------------------------
    MERGE INTO dbo.gold_GroupMemberships AS target
    USING (
        SELECT
            employee_id,
            group_id,
            TRY_CAST(assigned_date AS DATE) AS assigned_date,
            assigned_by
        FROM access_governance_lakehouse.dbo.silver_group_memberships
    ) AS source
    ON  target.EmployeeId = source.employee_id
    AND target.GroupId    = source.group_id

    WHEN MATCHED AND (
        ISNULL(CAST(target.AssignedDate AS VARCHAR(20)),'') <>
        ISNULL(CAST(source.assigned_date AS VARCHAR(20)),'') OR
        ISNULL(target.AssignedBy,'') <> ISNULL(source.assigned_by,'')
    ) THEN UPDATE SET
        target.AssignedDate = source.assigned_date,
        target.AssignedBy   = source.assigned_by

    WHEN NOT MATCHED BY TARGET THEN INSERT
        (EmployeeId, GroupId, AssignedDate, AssignedBy)
    VALUES
        (source.employee_id, source.group_id,
         source.assigned_date, source.assigned_by);

    -- --------------------------------------------------------
    -- MERGE 5: gold_GroupPermissions ← silver_group_permissions
    -- --------------------------------------------------------
    MERGE INTO dbo.gold_GroupPermissions AS target
    USING (
        SELECT
            group_id,
            resource_id,
            permission_level,
            TRY_CAST(granted_date AS DATE) AS granted_date
        FROM access_governance_lakehouse.dbo.silver_group_permissions
    ) AS source
    ON  target.GroupId    = source.group_id
    AND target.ResourceId = source.resource_id

    WHEN MATCHED AND (
        target.PermissionLevel <> source.permission_level OR
        ISNULL(CAST(target.GrantedDate AS VARCHAR(20)),'') <>
        ISNULL(CAST(source.granted_date AS VARCHAR(20)),'')
    ) THEN UPDATE SET
        target.PermissionLevel = source.permission_level,
        target.GrantedDate     = source.granted_date

    WHEN NOT MATCHED BY TARGET THEN INSERT
        (GroupId, ResourceId, PermissionLevel, GrantedDate)
    VALUES
        (source.group_id, source.resource_id,
         source.permission_level, source.granted_date);

    -- --------------------------------------------------------
    -- MERGE 6: gold_GroupInheritance ← silver_group_inheritance
    -- --------------------------------------------------------
    MERGE INTO dbo.gold_GroupInheritance AS target
    USING (
        SELECT child_group_id, parent_group_id, 'Full' AS inheritance_type
        FROM access_governance_lakehouse.dbo.silver_group_inheritance
    ) AS source
    ON  target.ChildGroupId  = source.child_group_id
    AND target.ParentGroupId = source.parent_group_id

    WHEN NOT MATCHED BY TARGET THEN INSERT
        (ChildGroupId, ParentGroupId, InheritanceType)
    VALUES
        (source.child_group_id, source.parent_group_id, source.inheritance_type);

END;
GO
