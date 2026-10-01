# Phase 2: Silver Lakehouse ETL

This guide explains how to transform the raw Bronze CSVs into cleansed, strongly typed Delta Parquet tables in the Silver layer using PySpark.

## 1. Importing the PySpark Notebook

1. In your Fabric Workspace, click **Import** and select **Notebook**.
2. Upload the `src/silver_pyspark/bronze_to_silver_etl.ipynb` file from this repository.
3. Open the imported Notebook.
4. In the top left corner, ensure your `access_governance_lakehouse` is attached to the notebook.

## 2. Understanding the ETL Logic

The notebook performs several critical Data Engineering tasks:
* **Schema Enforcement:** Instead of relying on Spark's `inferSchema` (which can be error prone and computationally expensive in production), the notebook explicitly defines `StructType` schemas for every incoming CSV.
* **Data Cleansing:** It strips whitespace, standardizes casing, and handles null values.
* **Format Conversion:** It reads the CSV files and writes them back to the Lakehouse as optimized **Delta Parquet** tables.
* **Overwrite/Append Logic:** The tables are written using `mode("overwrite")` to ensure idempotent pipeline runs.

## 3. Executing the Pipeline

1. Click **Run All** in the top ribbon of the notebook.
2. Spark will provision a session and execute the cells sequentially.
3. Once complete, refresh the **Tables** section in your Lakehouse explorer.

You should now see 7 clean Delta tables (e.g., `silver_employees`, `silver_resources`, etc.). The Silver layer is now ready for Data Warehousing.
