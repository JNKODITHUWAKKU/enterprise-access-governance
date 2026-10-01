# Phase 1: Data Generation & Ingestion

This guide explains how to generate the synthetic enterprise dataset and ingest it into the Microsoft Fabric Bronze layer.

## 1. Local Environment Setup

First, generate the raw data using the provided Python scripts. This simulates an export from an HR system (like Workday) and an Identity Provider (like Azure Active Directory).

1. Open a terminal and navigate to the `data_generator/` directory.
2. Install the required Python packages:
   ```bash
   pip install -r requirements.txt
   ```
3. Execute the generator script:
   ```bash
   python generate_data.py
   ```
4. The script will output 7 CSV files into the `data_generator/sample_output/` folder:
   * `employees.csv`
   * `departments.csv`
   * `security_groups.csv`
   * `group_memberships.csv`
   * `group_inheritance.csv`
   * `resources.csv`
   * `group_permissions.csv`

## 2. Fabric Lakehouse Creation

Now, we move to the cloud to set up our Data Lakehouse.

1. Log into your **Microsoft Fabric** environment.
2. Navigate to your desired Workspace (e.g., `AccessGovernance-Dev`).
3. Click **New** and select **Lakehouse**.
4. Name the Lakehouse `access_governance_lakehouse` and click Create.

## 3. Uploading to the Bronze Layer

In the Medallion Architecture, the Bronze layer holds raw, immutable data exactly as it arrived from the source.

1. In the Lakehouse explorer on the left, locate the **Files** section.
2. Click the `...` (More options) next to Files and select **New subfolder**.
3. Name the folder `bronze`.
4. Click the `...` next to your new `bronze` folder and select **Upload -> Upload files**.
5. Select all 7 CSV files generated in Step 1 and upload them.

Your Bronze layer is now populated and ready for Silver layer ETL processing.
