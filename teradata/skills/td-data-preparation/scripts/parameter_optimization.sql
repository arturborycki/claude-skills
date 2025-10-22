-- Parameter Optimization for TD_DATA_PREPARATION
-- Grid search and parameter tuning for UAF Model Preparation
-- Focus: Validation methods, filling strategies, quality thresholds

-- INSTRUCTIONS:
-- 1. Run uaf_data_preparation.sql first to prepare baseline data
-- 2. Configure parameter grids based on your data characteristics
-- 3. Execute parameter search iterations
-- 4. Select optimal parameters based on validation metrics

-- ============================================================================
-- STEP 1: Define Parameter Grid
-- ============================================================================

-- Create parameter combinations for grid search
DROP TABLE IF EXISTS data_prep_param_grid;
CREATE MULTISET TABLE data_prep_param_grid (
    param_id INTEGER,
    validation_type VARCHAR(50),
    fill_method VARCHAR(50),
    outlier_threshold DECIMAL(5,2),
    interpolation_method VARCHAR(50),
    missing_threshold_pct DECIMAL(5,2)
);

-- Populate parameter grid
INSERT INTO data_prep_param_grid VALUES
    -- Conservative parameters
    (1, 'strict', 'forward_fill', 3.0, 'linear', 5.0),
    (2, 'strict', 'backward_fill', 3.0, 'linear', 5.0),
    (3, 'strict', 'linear_interpolation', 3.0, 'linear', 5.0),
    (4, 'strict', 'mean_imputation', 3.0, 'none', 5.0),

    -- Moderate parameters
    (5, 'moderate', 'forward_fill', 2.5, 'linear', 10.0),
    (6, 'moderate', 'backward_fill', 2.5, 'spline', 10.0),
    (7, 'moderate', 'linear_interpolation', 2.5, 'linear', 10.0),
    (8, 'moderate', 'seasonal_adjustment', 2.5, 'seasonal', 10.0),

    -- Aggressive parameters
    (9, 'relaxed', 'forward_fill', 2.0, 'spline', 20.0),
    (10, 'relaxed', 'kalman_filter', 2.0, 'kalman', 20.0),
    (11, 'relaxed', 'seasonal_adjustment', 2.0, 'seasonal', 20.0),
    (12, 'relaxed', 'locf', 2.0, 'linear', 20.0);

-- ============================================================================
-- STEP 2: Validation Metrics Template
-- ============================================================================

-- Create table to store optimization results
DROP TABLE IF EXISTS data_prep_optimization_results;
CREATE MULTISET TABLE data_prep_optimization_results (
    param_id INTEGER,
    validation_type VARCHAR(50),
    fill_method VARCHAR(50),
    outlier_threshold DECIMAL(5,2),
    interpolation_method VARCHAR(50),
    missing_threshold_pct DECIMAL(5,2),
    -- Quality metrics
    completeness_score DECIMAL(10,6),
    consistency_score DECIMAL(10,6),
    outlier_detection_score DECIMAL(10,6),
    temporal_continuity_score DECIMAL(10,6),
    -- Overall score
    total_quality_score DECIMAL(10,6),
    -- Processing metrics
    records_processed INTEGER,
    records_imputed INTEGER,
    outliers_detected INTEGER,
    execution_time_sec DECIMAL(10,2),
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 3: Parameter Evaluation Functions
-- ============================================================================

-- Evaluate completeness for each parameter set
DROP TABLE IF EXISTS completeness_evaluation;
CREATE MULTISET TABLE completeness_evaluation AS (
    SELECT
        p.param_id,
        p.fill_method,
        -- Completeness after imputation
        CAST(COUNT(CASE WHEN d.prepared_value IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(10,6)) as completeness_pct,
        -- Missing value reduction
        CAST((initial_missing - final_missing) * 100.0 / NULLIFZERO(initial_missing) AS DECIMAL(10,6)) as improvement_pct
    FROM data_prep_param_grid p
    CROSS JOIN uaf_ready_data d
    CROSS JOIN (
        SELECT
            SUM(CASE WHEN prepared_value IS NULL THEN 1 ELSE 0 END) as initial_missing,
            COUNT(*) as total_records
        FROM uaf_ready_data
    ) baseline
    CROSS JOIN (
        SELECT
            SUM(has_null) as final_missing
        FROM uaf_ready_data
    ) after_prep
    GROUP BY p.param_id, p.fill_method, initial_missing, final_missing
) WITH DATA;

-- ============================================================================
-- STEP 4: Outlier Detection Performance
-- ============================================================================

-- Evaluate outlier detection sensitivity
DROP TABLE IF EXISTS outlier_evaluation;
CREATE MULTISET TABLE outlier_evaluation AS (
    SELECT
        p.param_id,
        p.outlier_threshold,
        -- Outlier statistics
        SUM(d.is_outlier) as outliers_detected,
        CAST(SUM(d.is_outlier) * 100.0 / COUNT(*) AS DECIMAL(10,6)) as outlier_pct,
        -- Precision: proportion of detected outliers that are true outliers
        CAST(SUM(CASE WHEN d.is_outlier = 1 AND ABS(d.prepared_value - avg_val) > p.outlier_threshold * stddev_val THEN 1 ELSE 0 END) * 100.0 /
             NULLIFZERO(SUM(d.is_outlier)) AS DECIMAL(10,6)) as outlier_precision
    FROM data_prep_param_grid p
    CROSS JOIN uaf_ready_data d
    CROSS JOIN (
        SELECT AVG(prepared_value) as avg_val, STDDEV(prepared_value) as stddev_val
        FROM uaf_ready_data
    ) stats
    GROUP BY p.param_id, p.outlier_threshold, avg_val, stddev_val
) WITH DATA;

-- ============================================================================
-- STEP 5: Temporal Continuity Assessment
-- ============================================================================

-- Evaluate temporal continuity and smoothness
DROP TABLE IF EXISTS temporal_evaluation;
CREATE MULTISET TABLE temporal_evaluation AS (
    SELECT
        p.param_id,
        p.interpolation_method,
        -- Smoothness metrics
        STDDEV(ABS(d.prepared_value - LAG(d.prepared_value) OVER (ORDER BY d.time_index))) as change_volatility,
        -- Continuity score (inverse of volatility, normalized)
        1.0 / (1.0 + STDDEV(ABS(d.prepared_value - LAG(d.prepared_value) OVER (ORDER BY d.time_index)))) as continuity_score,
        -- Gap analysis
        COUNT(CASE WHEN d.has_null = 1 THEN 1 END) as remaining_gaps
    FROM data_prep_param_grid p
    CROSS JOIN uaf_ready_data d
    GROUP BY p.param_id, p.interpolation_method
) WITH DATA;

-- ============================================================================
-- STEP 6: Overall Quality Score Calculation
-- ============================================================================

-- Calculate composite quality score for each parameter set
INSERT INTO data_prep_optimization_results
SELECT
    p.param_id,
    p.validation_type,
    p.fill_method,
    p.outlier_threshold,
    p.interpolation_method,
    p.missing_threshold_pct,
    -- Weighted quality metrics
    COALESCE(c.completeness_pct / 100.0, 0) as completeness_score,
    COALESCE(1.0 - (p.missing_threshold_pct / 100.0), 0) as consistency_score,
    COALESCE(o.outlier_precision / 100.0, 0) as outlier_detection_score,
    COALESCE(t.continuity_score, 0) as temporal_continuity_score,
    -- Total score (weighted average)
    (COALESCE(c.completeness_pct / 100.0, 0) * 0.30 +
     COALESCE(1.0 - (p.missing_threshold_pct / 100.0), 0) * 0.20 +
     COALESCE(o.outlier_precision / 100.0, 0) * 0.25 +
     COALESCE(t.continuity_score, 0) * 0.25) as total_quality_score,
    -- Processing metrics
    (SELECT COUNT(*) FROM uaf_ready_data) as records_processed,
    (SELECT SUM(has_null) FROM uaf_ready_data) as records_imputed,
    COALESCE(o.outliers_detected, 0) as outliers_detected,
    0.0 as execution_time_sec,  -- Placeholder
    CURRENT_TIMESTAMP as created_timestamp
FROM data_prep_param_grid p
LEFT JOIN completeness_evaluation c ON p.param_id = c.param_id
LEFT JOIN outlier_evaluation o ON p.param_id = o.param_id
LEFT JOIN temporal_evaluation t ON p.param_id = t.param_id;

-- ============================================================================
-- STEP 7: Optimal Parameter Selection
-- ============================================================================

-- Rank parameters by total quality score
SELECT
    'Parameter Optimization Results' as ReportType,
    param_id,
    validation_type,
    fill_method,
    outlier_threshold,
    interpolation_method,
    missing_threshold_pct,
    CAST(completeness_score AS DECIMAL(6,4)) as Completeness,
    CAST(consistency_score AS DECIMAL(6,4)) as Consistency,
    CAST(outlier_detection_score AS DECIMAL(6,4)) as OutlierDetection,
    CAST(temporal_continuity_score AS DECIMAL(6,4)) as TemporalContinuity,
    CAST(total_quality_score AS DECIMAL(6,4)) as TotalScore,
    RANK() OVER (ORDER BY total_quality_score DESC) as Rank
FROM data_prep_optimization_results
ORDER BY total_quality_score DESC;

-- Best parameter configuration
SELECT
    'OPTIMAL CONFIGURATION' as ConfigType,
    validation_type as RecommendedValidationType,
    fill_method as RecommendedFillMethod,
    outlier_threshold as RecommendedOutlierThreshold,
    interpolation_method as RecommendedInterpolation,
    missing_threshold_pct as RecommendedMissingThreshold,
    CAST(total_quality_score AS DECIMAL(6,4)) as QualityScore
FROM data_prep_optimization_results
ORDER BY total_quality_score DESC
FETCH FIRST 1 ROW ONLY;

-- ============================================================================
-- STEP 8: Sensitivity Analysis
-- ============================================================================

-- Analyze parameter sensitivity
SELECT
    'Sensitivity Analysis' as AnalysisType,
    fill_method,
    COUNT(*) as ConfigCount,
    AVG(total_quality_score) as AvgScore,
    STDDEV(total_quality_score) as ScoreVariance,
    MIN(total_quality_score) as MinScore,
    MAX(total_quality_score) as MaxScore
FROM data_prep_optimization_results
GROUP BY fill_method
ORDER BY AvgScore DESC;

-- Outlier threshold sensitivity
SELECT
    'Outlier Threshold Impact' as AnalysisType,
    outlier_threshold,
    AVG(outlier_detection_score) as AvgOutlierScore,
    AVG(total_quality_score) as AvgTotalScore,
    COUNT(*) as ConfigCount
FROM data_prep_optimization_results
GROUP BY outlier_threshold
ORDER BY outlier_threshold;

-- ============================================================================
-- STEP 9: Export Optimal Parameters for Production
-- ============================================================================

-- Export optimal configuration
DROP TABLE IF EXISTS optimal_data_prep_config;
CREATE MULTISET TABLE optimal_data_prep_config AS (
    SELECT
        validation_type,
        fill_method,
        outlier_threshold,
        interpolation_method,
        missing_threshold_pct,
        total_quality_score,
        'PRODUCTION' as config_status,
        CURRENT_TIMESTAMP as config_timestamp
    FROM data_prep_optimization_results
    ORDER BY total_quality_score DESC
    FETCH FIRST 1 ROW ONLY
) WITH DATA;

SELECT * FROM optimal_data_prep_config;

/*
PARAMETER OPTIMIZATION CHECKLIST:
□ Define comprehensive parameter grid
□ Run grid search across all combinations
□ Evaluate multiple quality dimensions:
  - Completeness (missing data handling)
  - Consistency (threshold appropriateness)
  - Outlier detection accuracy
  - Temporal continuity
□ Calculate composite quality score
□ Perform sensitivity analysis
□ Select optimal configuration
□ Document parameter choices and rationale

OPTIMIZATION DIMENSIONS:
1. Validation Type: strict, moderate, relaxed
2. Fill Method: forward_fill, backward_fill, interpolation, mean, seasonal
3. Outlier Threshold: 2.0, 2.5, 3.0 sigma
4. Interpolation Method: linear, spline, seasonal, kalman
5. Missing Threshold: 5%, 10%, 20% acceptable missing data

SCORING WEIGHTS:
- Completeness: 30% (data coverage)
- Consistency: 20% (validation rigor)
- Outlier Detection: 25% (anomaly precision)
- Temporal Continuity: 25% (smoothness)

NEXT STEPS:
1. Review optimization results and rankings
2. Validate optimal parameters on holdout data
3. Apply optimal configuration to production workflow
4. Monitor performance and adjust if needed
5. Document parameter selection rationale
6. Use optimal_data_prep_config in td_data_preparation_workflow.sql
*/
