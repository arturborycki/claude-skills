-- =====================================================
-- Table Discovery and Metadata Extraction
-- =====================================================
-- Purpose: Analyze table structure and classify columns
-- Output: Table metadata, column list, and data types
-- =====================================================

-- =====================================================
-- 1. TABLE METADATA RETRIEVAL
-- =====================================================

-- Get comprehensive table information
SELECT
    DatabaseName,
    TableName,
    TableKind,
    CreateTimeStamp,
    LastAlterTimeStamp,
    RequestText as CreateStatement
FROM DBC.TablesV
WHERE DatabaseName = '{database}'
  AND TableName = '{table_name}'
;

-- Get column definitions and data types
SELECT
    ColumnName,
    ColumnType,
    ColumnLength,
    DecimalTotalDigits,
    DecimalFractionalDigits,
    Nullable,
    DefaultValue,
    ColumnFormat,
    ColumnTitle
FROM DBC.ColumnsV
WHERE DatabaseName = '{database}'
  AND TableName = '{table_name}'
ORDER BY ColumnId
;

-- =====================================================
-- 2. BASIC TABLE STATISTICS
-- =====================================================

-- Get row count and table size
SELECT
    COUNT(*) as total_rows,
    CURRENT_TIMESTAMP as profiling_timestamp
FROM {database}.{table_name}
;

-- Get table storage statistics
SELECT
    DatabaseName,
    TableName,
    SUM(CurrentPerm) / (1024*1024) as size_mb,
    MAX(CreateTimeStamp) as created_date,
    MAX(LastAlterTimeStamp) as last_modified
FROM DBC.TableSizeV
WHERE DatabaseName = '{database}'
  AND TableName = '{table_name}'
GROUP BY DatabaseName, TableName
;

-- =====================================================
-- 3. COLUMN CLASSIFICATION
-- =====================================================

-- Classify columns by data type category
SELECT
    ColumnName,
    ColumnType,
    CASE
        WHEN ColumnType IN ('I', 'I1', 'I2', 'I8', 'BI', 'BF', 'F', 'D', 'N')
            THEN 'NUMERIC'
        WHEN ColumnType IN ('CF', 'CV', 'DA', 'AT', 'TS', 'TZ', 'SZ', 'YR', 'YM', 'MO', 'DY', 'HR', 'MI', 'SC', 'MS', 'US')
            THEN 'DATETIME'
        WHEN ColumnType IN ('CO', 'BO')
            THEN 'BINARY'
        ELSE 'CHARACTER'
    END as column_category,
    CASE
        WHEN ColumnType IN ('I', 'I1', 'I2', 'I8') THEN 'INTEGER'
        WHEN ColumnType IN ('BI') THEN 'BIGINT'
        WHEN ColumnType IN ('BF', 'F') THEN 'FLOAT'
        WHEN ColumnType IN ('D') THEN 'DECIMAL'
        WHEN ColumnType IN ('N') THEN 'NUMBER'
        WHEN ColumnType IN ('CF') THEN 'CHAR'
        WHEN ColumnType IN ('CV') THEN 'VARCHAR'
        WHEN ColumnType IN ('DA') THEN 'DATE'
        WHEN ColumnType IN ('TS') THEN 'TIMESTAMP'
        WHEN ColumnType IN ('AT') THEN 'TIME'
        WHEN ColumnType IN ('YR', 'YM', 'MO', 'DY', 'HR', 'MI', 'SC') THEN 'INTERVAL'
        WHEN ColumnType IN ('CO') THEN 'CLOB'
        WHEN ColumnType IN ('BO') THEN 'BLOB'
        ELSE 'OTHER'
    END as data_type_name,
    Nullable
FROM DBC.ColumnsV
WHERE DatabaseName = '{database}'
  AND TableName = '{table_name}'
ORDER BY ColumnId
;

-- =====================================================
-- 4. SAMPLE DATA PREVIEW
-- =====================================================

-- Get sample rows for manual inspection
SELECT TOP 10 *
FROM {database}.{table_name}
SAMPLE 10
;

-- =====================================================
-- 5. COLUMN PROFILING CLASSIFICATION
-- =====================================================

-- Determine which profiling approach for each column
WITH column_info AS (
    SELECT
        ColumnName,
        ColumnType,
        CASE
            WHEN ColumnType IN ('I', 'I1', 'I2', 'I8', 'BI', 'BF', 'F', 'D', 'N')
                THEN 'NUMERIC_PROFILE'
            WHEN ColumnType IN ('CF', 'CV')
                THEN 'CATEGORICAL_PROFILE'
            WHEN ColumnType IN ('DA', 'AT', 'TS', 'TZ', 'SZ')
                THEN 'DATETIME_PROFILE'
            WHEN ColumnType IN ('CO', 'BO')
                THEN 'BINARY_NO_PROFILE'
            ELSE 'TEXT_PROFILE'
        END as profiling_strategy
    FROM DBC.ColumnsV
    WHERE DatabaseName = '{database}'
      AND TableName = '{table_name}'
)
SELECT
    profiling_strategy,
    COUNT(*) as column_count,
    LISTAGG(ColumnName, ', ') WITHIN GROUP (ORDER BY ColumnName) as columns
FROM column_info
GROUP BY profiling_strategy
ORDER BY column_count DESC
;

-- =====================================================
-- 6. GENERATE COLUMN LISTS FOR PROFILING
-- =====================================================

-- Numeric columns for univariate statistics
SELECT
    'Numeric Columns: ' || LISTAGG(ColumnName, ', ') WITHIN GROUP (ORDER BY ColumnName) as numeric_column_list
FROM DBC.ColumnsV
WHERE DatabaseName = '{database}'
  AND TableName = '{table_name}'
  AND ColumnType IN ('I', 'I1', 'I2', 'I8', 'BI', 'BF', 'F', 'D', 'N')
;

-- Categorical columns for frequency analysis
-- (Character columns with reasonable cardinality)
SELECT
    'Categorical Columns: ' || LISTAGG(ColumnName, ', ') WITHIN GROUP (ORDER BY ColumnName) as categorical_column_list
FROM DBC.ColumnsV
WHERE DatabaseName = '{database}'
  AND TableName = '{table_name}'
  AND ColumnType IN ('CF', 'CV')
  AND ColumnLength <= 100  -- Reasonable size for categorical
;

-- Date/Time columns for temporal profiling
SELECT
    'DateTime Columns: ' || LISTAGG(ColumnName, ', ') WITHIN GROUP (ORDER BY ColumnName) as datetime_column_list
FROM DBC.ColumnsV
WHERE DatabaseName = '{database}'
  AND TableName = '{table_name}'
  AND ColumnType IN ('DA', 'AT', 'TS', 'TZ', 'SZ')
;

-- =====================================================
-- 7. IDENTIFY POTENTIAL PRIMARY KEY
-- =====================================================

-- Find columns that might be primary keys (unique identifiers)
SELECT
    i.IndexName,
    i.UniqueFlag,
    LISTAGG(ic.ColumnName, ', ') WITHIN GROUP (ORDER BY ic.ColumnPosition) as key_columns
FROM DBC.IndicesV i
INNER JOIN DBC.IndexColumnsV ic
    ON i.DatabaseName = ic.DatabaseName
    AND i.TableName = ic.TableName
    AND i.IndexName = ic.IndexName
WHERE i.DatabaseName = '{database}'
  AND i.TableName = '{table_name}'
  AND i.UniqueFlag = 'Y'
GROUP BY i.IndexName, i.UniqueFlag
;

-- =====================================================
-- 8. TABLE QUALITY PRELIMINARY ASSESSMENT
-- =====================================================

-- Quick quality check
WITH row_counts AS (
    SELECT COUNT(*) as total_rows
    FROM {database}.{table_name}
),
column_counts AS (
    SELECT COUNT(*) as total_columns
    FROM DBC.ColumnsV
    WHERE DatabaseName = '{database}'
      AND TableName = '{table_name}'
)
SELECT
    rc.total_rows,
    cc.total_columns,
    CASE
        WHEN rc.total_rows < 10 THEN 'INSUFFICIENT - Less than 10 rows'
        WHEN rc.total_rows < 100 THEN 'MINIMAL - Limited statistical power'
        WHEN rc.total_rows < 1000 THEN 'ADEQUATE - Basic profiling possible'
        WHEN rc.total_rows < 1000000 THEN 'GOOD - Full profiling recommended'
        ELSE 'LARGE - Consider sampling for efficiency'
    END as data_volume_assessment,
    CASE
        WHEN cc.total_columns < 5 THEN 'FEW - Limited dimensions'
        WHEN cc.total_columns < 20 THEN 'MODERATE - Standard profiling'
        WHEN cc.total_columns < 100 THEN 'MANY - Comprehensive profiling'
        ELSE 'VERY MANY - Consider focused profiling'
    END as dimensionality_assessment
FROM row_counts rc, column_counts cc
;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--
-- 2. Execute each section sequentially
--
-- 3. Review outputs to understand:
--    - Table structure and metadata
--    - Column data types and categories
--    - Appropriate profiling strategies per column
--    - Potential primary keys
--    - Data volume considerations
--
-- 4. Use column lists generated to populate subsequent profiling scripts
--
-- =====================================================
