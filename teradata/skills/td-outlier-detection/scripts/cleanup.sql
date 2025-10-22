-- =====================================================
-- Cleanup Script - Table Management
-- =====================================================
-- Purpose: Clean up intermediate tables and resources
-- Warning: This will DROP tables - ensure you want to proceed
-- =====================================================

-- Option 1: Clean up ALL intermediate tables
/*
DROP TABLE IF EXISTS {database}.outlier_fit_out;
DROP TABLE IF EXISTS {database}.outlier_detection_out;
DROP TABLE IF EXISTS {database}.clean_data_out;
DROP TABLE IF EXISTS {database}.outlier_evaluation_out;
*/

-- Option 2: Selective cleanup - Keep fitted detector and final results
/*
-- Keep: outlier_fit_out, outlier_detection_out, clean_data_out
DROP TABLE IF EXISTS {database}.outlier_evaluation_out;
*/

-- Option 3: Archive before cleanup
/*
CREATE TABLE {database}.outlier_fit_archive AS
    SELECT *, CURRENT_TIMESTAMP as archived_date
    FROM {database}.outlier_fit_out
    WITH DATA;

CREATE TABLE {database}.outlier_detection_archive AS
    SELECT *, CURRENT_TIMESTAMP as archived_date
    FROM {database}.outlier_detection_out
    WITH DATA;

DROP TABLE IF EXISTS {database}.outlier_fit_out;
DROP TABLE IF EXISTS {database}.outlier_detection_out;
*/

-- Option 4: Check table sizes before cleanup
SELECT
    DatabaseName,
    TableName,
    CAST(SUM(CurrentPerm) / (1024*1024) AS DECIMAL(10,2)) as size_mb,
    CAST(SUM(CurrentPerm) / (1024*1024*1024) AS DECIMAL(10,2)) as size_gb,
    SUM(TableCount) as row_count
FROM DBC.TableSizeV
WHERE DatabaseName = '{database}'
AND TableName IN (
    'outlier_fit_out',
    'outlier_detection_out',
    'clean_data_out',
    'outlier_evaluation_out'
)
GROUP BY DatabaseName, TableName
ORDER BY size_mb DESC;

-- Option 5: Verify existing tables
SELECT
    TableName,
    CreateTimeStamp,
    LastAlterTimeStamp
FROM DBC.TablesV
WHERE DatabaseName = '{database}'
AND (
    TableName LIKE '%_out'
    OR TableName LIKE '%_archive'
    OR TableName LIKE '%outlier%'
    OR TableName LIKE '%clean%'
)
ORDER BY CreateTimeStamp DESC;

-- Option 6: Collect Statistics after cleanup
/*
COLLECT STATISTICS ON {database}.outlier_fit_archive;
COLLECT STATISTICS ON {database}.outlier_detection_archive;
*/

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Review the options above
-- 2. Uncomment the section that matches your cleanup needs
-- 3. Replace {database} with your actual database name
-- 4. Execute the selected section
-- 5. Verify cleanup completed successfully
--
-- CAUTION: DROP TABLE operations cannot be undone
-- =====================================================
