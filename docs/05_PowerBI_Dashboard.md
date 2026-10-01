# Phase 5: Power BI Risk Dashboard

This guide explains how to connect Power BI to the Data Warehouse to visualize the security threats.

## 1. Creating the Semantic Model

Because we built the data architecture inside Microsoft Fabric, we can utilize **DirectLake / DirectQuery** mode, meaning the dashboard queries the warehouse in real time without needing to import or refresh datasets.

1. Open your `access_governance_warehouse`.
2. In the top ribbon, click **New semantic model**.
3. Name it `PowerBi-Model`.
4. Select the 5 views we created in Phase 3 (`vw_AllUsers`, `vw_AllResources`, `vw_RiskSummary`, `vw_ResourceRiskHeatmap`, `vw_ToxicAccessPaths`).
5. Click Confirm.

## 2. Building the Dashboard

Open the Semantic Model and click **New report** to open the blank canvas. Build the following 5 pages to complete the command center:

### Page 1: Executive Summary
* **Visuals:** Card visuals displaying `TotalToxicPaths`, `CriticalPaths`, and `AffectedContractors` from the `vw_RiskSummary` table.
* **Purpose:** Provides C-suite leadership with a high level overview of the current risk landscape.

### Page 2: Toxic Paths Detail
* **Visuals:** A full page Matrix/Table pulling from `vw_ToxicAccessPaths`. 
* **Details:** Include the `AccessPath` column, which contains the full graph string (e.g., `User -> Group A -> inherits Group B -> Admin Access`). Add slicers for `Sensitivity` and `PathType`.

### Page 3: Risk Heatmap
* **Visuals:** A Matrix visual with `ResourceName` on Rows, `PermissionLevel` on Columns, and `ToxicPathCount` as Values.
* **Details:** Apply conditional formatting (Gradient Background) to the values so cells with the highest risk glow dark red.

### Page 4: Group Analysis
* **Visuals:** A Treemap showing `InheritedGroup` sizes, and a Stacked Bar Chart comparing Direct vs Inherited paths.
* **Purpose:** Allows Entra ID administrators to identify which specific security groups are poorly configured and causing cascading vulnerabilities.

### Page 5: Contractor Risk Profile
* **Visuals:** A searchable Slicer for `Name`, a Multi-row card for employee details, and a Table for their specific access.
* **Purpose:** Allows HR or Security to audit a specific individual and see their exact footprint across the network.

Once complete, click **Save**. The end-to-end Enterprise Access Governance platform is now fully operational!
