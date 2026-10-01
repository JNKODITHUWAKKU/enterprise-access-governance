# Phase 3: Gold Warehouse Analytics

This guide details how to build the dimensional Data Warehouse, including the T-SQL tables, incremental Upsert logic, and advanced Graph Analytics views.

## 1. Creating the Data Warehouse

1. In your Fabric Workspace, click **New** and select **Warehouse**.
2. Name it `access_governance_warehouse`.
3. Wait for the SQL endpoint to provision.

## 2. Executing the T-SQL Scripts

You will execute three SQL scripts located in the `src/gold_tsql/` folder. Open a **New SQL query** window in the Warehouse for each step.

### Step A: Table Creation
Copy and run `01_create_tables.sql`. 
* **Purpose:** This creates the physical Gold tables (`gold_Users`, `gold_Groups`, etc.). 
* **Key Feature:** It implements `NONCLUSTERED NOT ENFORCED` Primary Keys, which are optimized for distributed columnar storage in Fabric while still providing semantic relationships for Power BI.

### Step B: The Upsert Stored Procedure
Copy and run `02_create_stored_proc.sql`.
* **Purpose:** This creates `dbo.usp_UpsertGoldLayer`.
* **Key Feature:** Instead of blindly dropping and recreating tables, this procedure uses T-SQL `MERGE` statements. It compares the incoming `silver` Delta tables against the existing `gold` tables, inserting new records and updating changed records. This guarantees zero downtime for downstream reports.

### Step C: Analytics & Graph Views
Copy and run `03_create_views.sql`.
* **Purpose:** This creates 5 semantic views optimized for direct reporting.
* **Key Feature:** The `vw_ToxicAccessPaths` view contains the core security logic. Since native SQL Graph is restricted in Fabric Warehouses, this view uses recursive Common Table Expressions (CTEs) and deeply nested `JOIN` logic to traverse Active Directory inheritance. It mathematically identifies any Contractor who has inherited Admin/Write access to High/Critical systems.

## 3. Initializing the Data

To populate the Gold layer for the first time:
1. Open a new query window.
2. Execute the following command:
   ```sql
   EXEC dbo.usp_UpsertGoldLayer;
   ```
3. Verify the data by querying `SELECT * FROM dbo.vw_ToxicAccessPaths;`. You should see the detected vulnerabilities.
