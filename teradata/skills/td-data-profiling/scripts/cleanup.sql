-- =====================================================
-- Cleanup Script - Remove Profiling Tables
-- =====================================================
-- Purpose: Clean up temporary profiling tables and objects
-- WARNING: This will delete all profiling results
-- =====================================================

-- =====================================================
-- SAFETY CHECK
-- =====================================================

-- List all profiling tables before deletion
SELECT
    DatabaseName,
    TableName,
    CreateTimeStamp,
    TableKind
FROM DBC.TablesV
WHERE DatabaseName = '{database}'
  AND TableName LIKE '{table_name}%profile%'
ORDER BY TableName
;

-- Show row counts before deletion
SELECT
    '{table_name}_numeric_profile' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name}_numeric_profile) as row_count
UNION ALL
SELECT
    '{table_name}_categorical_profile' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name}_categorical_profile) as row_count
UNION ALL
SELECT
    '{table_name}_distribution_profile' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name}_distribution_profile) as row_count
UNION ALL
SELECT
    '{table_name}_correlation_profile' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name}_correlation_profile) as row_count
UNION ALL
SELECT
    '{table_name}_outlier_profile' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name}_outlier_profile) as row_count
UNION ALL
SELECT
    '{table_name}_quality_scorecard' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name}_quality_scorecard) as row_count
UNION ALL
SELECT
    '{table_name}_profiling_report' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name}_profiling_report) as row_count
;

-- =====================================================
-- OPTION 1: DROP ALL PROFILING TABLES
-- =====================================================

-- WARNING: This will permanently delete all profiling results
-- Uncomment to execute

-- Drop numeric profiling table
DROP TABLE {database}.{table_name}_numeric_profile;

-- Drop categorical profiling table
DROP TABLE {database}.{table_name}_categorical_profile;

-- Drop distribution profiling table
DROP TABLE {database}.{table_name}_distribution_profile;

-- Drop correlation profiling table
DROP TABLE {database}.{table_name}_correlation_profile;

-- Drop outlier profiling table
DROP TABLE {database}.{table_name}_outlier_profile;

-- Drop quality scorecard table
DROP TABLE {database}.{table_name}_quality_scorecard;

-- Drop final profiling report table
DROP TABLE {database}.{table_name}_profiling_report;

-- =====================================================
-- OPTION 2: ARCHIVE BEFORE DELETION
-- =====================================================

-- Create archive tables with timestamp before deletion
-- This allows you to keep historical profiling results

-- Archive numeric profile
CREATE TABLE {database}.{table_name}_numeric_profile_archive_${profiling_date} AS
SELECT *, CURRENT_TIMESTAMP as archived_at
FROM {database}.{table_name}_numeric_profile
WITH DATA;

-- Archive categorical profile
CREATE TABLE {database}.{table_name}_categorical_profile_archive_${profiling_date} AS
SELECT *, CURRENT_TIMESTAMP as archived_at
FROM {database}.{table_name}_categorical_profile
WITH DATA;

-- Archive distribution profile
CREATE TABLE {database}.{table_name}_distribution_profile_archive_${profiling_date} AS
SELECT *, CURRENT_TIMESTAMP as archived_at
FROM {database}.{table_name}_distribution_profile
WITH DATA;

-- Archive correlation profile
CREATE TABLE {database}.{table_name}_correlation_profile_archive_${profiling_date} AS
SELECT *, CURRENT_TIMESTAMP as archived_at
FROM {database}.{table_name}_correlation_profile
WITH DATA;

-- Archive outlier profile
CREATE TABLE {database}.{table_name}_outlier_profile_archive_${profiling_date} AS
SELECT *, CURRENT_TIMESTAMP as archived_at
FROM {database}.{table_name}_outlier_profile
WITH DATA;

-- Archive quality scorecard
CREATE TABLE {database}.{table_name}_quality_scorecard_archive_${profiling_date} AS
SELECT *, CURRENT_TIMESTAMP as archived_at
FROM {database}.{table_name}_quality_scorecard
WITH DATA;

-- Archive final report
CREATE TABLE {database}.{table_name}_profiling_report_archive_${profiling_date} AS
SELECT *, CURRENT_TIMESTAMP as archived_at
FROM {database}.{table_name}_profiling_report
WITH DATA;

-- Then drop the original tables (same as Option 1)

-- =====================================================
-- OPTION 3: SELECTIVE CLEANUP
-- =====================================================

-- Keep final report and quality scorecard, drop intermediate tables

-- Drop intermediate profiling tables
DROP TABLE {database}.{table_name}_numeric_profile;
DROP TABLE {database}.{table_name}_categorical_profile;
DROP TABLE {database}.{table_name}_distribution_profile;
DROP TABLE {database}.{table_name}_correlation_profile;
DROP TABLE {database}.{table_name}_outlier_profile;

-- Keep these tables for reference:
-- {database}.{table_name}_quality_scorecard
-- {database}.{table_name}_profiling_report

-- =====================================================
-- VERIFY CLEANUP
-- =====================================================

-- Verify tables have been dropped
SELECT
    DatabaseName,
    TableName
FROM DBC.TablesV
WHERE DatabaseName = '{database}'
  AND TableName LIKE '{table_name}%profile%'
ORDER BY TableName
;

-- Check remaining profiling tables
SELECT
    'Remaining Profiling Tables:' as status,
    COUNT(*) as table_count
FROM DBC.TablesV
WHERE DatabaseName = '{database}'
  AND TableName LIKE '{table_name}%profile%'
;

-- =====================================================
-- CLEANUP ARCHIVED TABLES (OPTIONAL)
-- =====================================================

-- Remove old archived profiling tables (older than 90 days)
-- Uncomment and modify date as needed

/*
SELECT
    'DROP TABLE ' || DatabaseName || '.' || TableName || ';' as drop_statement
FROM DBC.TablesV
WHERE DatabaseName = '{database}'
  AND TableName LIKE '{table_name}%archive%'
  AND CreateTimeStamp < CURRENT_DATE - 90
ORDER BY CreateTimeStamp;
*/

-- =====================================================
-- SPACE RECLAMATION
-- =====================================================

-- Check space freed after cleanup
SELECT
    DatabaseName,
    SUM(CurrentPerm) / (1024*1024*1024) as freed_space_gb
FROM DBC.TableSizeV
WHERE DatabaseName = '{database}'
  AND TableName LIKE '{table_name}%profile%'
GROUP BY DatabaseName
;

-- =====================================================
-- CLEANUP SUMMARY
-- =====================================================

-- Generate cleanup summary
SELECT
    '{database}.{table_name}' as source_table,
    'Profiling Cleanup' as operation,
    CASE
        WHEN EXISTS (SELECT 1 FROM DBC.TablesV WHERE DatabaseName = '{database}' AND TableName = '{table_name}_numeric_profile')
        THEN 'NOT CLEANED - Tables still exist'
        ELSE 'CLEANED - Tables removed'
    END as cleanup_status,
    CURRENT_TIMESTAMP as cleanup_timestamp,
    'Review archived tables if needed for historical comparison' as notes
;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    ${profiling_date} - Date/timestamp for archiving (e.g., 20240101)
--
-- 2. Choose cleanup option:
--    Option 1: Complete deletion (fastest, no history)
--    Option 2: Archive then delete (keeps history)
--    Option 3: Selective (keeps summary tables)
--
-- 3. Review safety check queries before executing drops
--
-- 4. Uncomment DROP statements when ready to execute
--
-- 5. Run verification queries to confirm cleanup
--
-- 6. Consider:
--    - Export reports to file before cleanup
--    - Keep quality scorecards for trending
--    - Archive for compliance or auditing
--    - Schedule periodic cleanup of old archives
--
-- WARNING: Dropped tables cannot be recovered unless archived
-- Always verify table contents before deletion
-- Consider testing on non-production environment first
--
-- =====================================================
