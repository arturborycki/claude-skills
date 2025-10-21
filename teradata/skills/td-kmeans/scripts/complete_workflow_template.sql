-- Complete TD_KMeans Workflow Template
-- Replace placeholders with your actual table information

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {USER_TABLE} with your table name
-- 3. Replace {TARGET_COLUMN} with your target variable
-- 4. Replace {ID_COLUMN} with your unique identifier column
-- 5. Update column lists based on your table structure analysis

-- ============================================================================
-- PREREQUISITE: Run table_analysis.sql first to understand your data structure
-- ============================================================================

-- 1. Train-Test Split (if applicable)
DROP TABLE IF EXISTS train_test_out;
CREATE MULTISET TABLE train_test_out AS (
    SELECT * FROM TD_TrainTestSplit (
        ON {USER_DATABASE}.{USER_TABLE} as InputTable
        USING
        IDColumn ('{ID_COLUMN}')
        TrainSize (0.8)
        TestSize (0.2)
        Seed (42)
    ) as dt
) WITH DATA;

-- 2. Create Train and Test Tables
DROP TABLE IF EXISTS {USER_TABLE}_train;
CREATE MULTISET TABLE {USER_TABLE}_train AS (
    SELECT * FROM train_test_out WHERE TD_IsTrainRow = 1
) WITH DATA;

DROP TABLE IF EXISTS {USER_TABLE}_test;
CREATE MULTISET TABLE {USER_TABLE}_test AS (
    SELECT * FROM train_test_out WHERE TD_IsTrainRow = 0
) WITH DATA;

-- 3. TD_KMeans Execution
DROP TABLE IF EXISTS td_kmeans_results;
CREATE MULTISET TABLE td_kmeans_results AS (
    SELECT * FROM TD_KMeans (
        ON {USER_DATABASE}.{USER_TABLE} as InputTable
        USING
        -- Add function-specific parameters here
        -- Refer to Teradata documentation for TD_KMeans parameters
    ) as dt
) WITH DATA;

-- 4. Model Prediction
DROP TABLE IF EXISTS td_kmeans_predictions;
CREATE MULTISET TABLE td_kmeans_predictions AS (
    SELECT * FROM TD_KMeansPredict (
        ON {USER_TABLE}_test as InputTable
        ON td_kmeans_results as ModelTable DIMENSION
        USING
        IDColumn ('{ID_COLUMN}')
    ) as dt
) WITH DATA;

-- 5. Results Analysis
SELECT * FROM td_kmeans_results ORDER BY 1;

-- Cleanup (optional)
-- DROP TABLE train_test_out;
-- DROP TABLE {USER_TABLE}_train;
-- DROP TABLE {USER_TABLE}_test;
