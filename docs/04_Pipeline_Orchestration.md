# Phase 4: Pipeline Orchestration & Alerting

This guide explains how to automate the entire ELT process and configure dynamic email alerts using Azure Data Factory (Fabric Pipelines).

## 1. Creating the Pipeline

1. In your Fabric Workspace, click **New** and select **Data pipeline**.
2. Name it `AccessGovernance-E2E-Pipeline`.

## 2. Building the Orchestration Flow

Add the following activities to the pipeline canvas and connect them sequentially (On Success):

### Activity 1: Run-Silver-ETL (Notebook)
* **Type:** Notebook
* **Settings:** Select your `bronze_to_silver_etl` notebook.
* **Purpose:** Triggers the PySpark cluster to process the raw data.

### Activity 2: Run-Gold-Upsert (Script)
* **Type:** Script
* **Connection:** Select `access_governance_warehouse`.
* **Script:** `EXEC dbo.usp_UpsertGoldLayer;`
* **Purpose:** Triggers the SQL Stored Procedure to safely merge the new data.

### Activity 3: Check-Toxic-Paths (Lookup)
* **Type:** Lookup
* **Connection:** Select `access_governance_warehouse`.
* **Query:** `SELECT COUNT(*) AS PathCount FROM dbo.vw_ToxicAccessPaths`
* **Settings:** Check "First row only".
* **Purpose:** Dynamically queries the warehouse to see if any security vulnerabilities currently exist.

### Activity 4: If-Risks-Found (If Condition)
* **Type:** If Condition
* **Expression:** `@greater(activity('Check-Toxic-Paths').output.firstRow.PathCount, 0)`
* **Purpose:** Acts as a logic gate. Only proceeds if toxic paths are detected.

### Activity 5: Alert SecOps (Office 365 Outlook)
* *Inside the "True" path of the If Condition:*
* **Type:** Office 365 Outlook
* **To:** [Your Security Team Email]
* **Subject:** `URGENT: Toxic Access Paths Detected in Azure Data Platform`
* **Body:** Use dynamic content to inject the exact count:
  `@concat('Security Alert: The Access Governance pipeline just finished and detected ', activity('Check-Toxic-Paths').output.firstRow.PathCount, ' toxic access paths. Please check the Power BI Risk Dashboard immediately.')`

## 3. Configuring the Trigger

In production environments, you have set the pipeline Trigger to **Storage Events** (Blob Created). This ensures the pipeline executes the exact millisecond a new log file drops into the Bronze layer, achieving near real time processing.