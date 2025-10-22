-- Parameter Optimization for TD_CROSS_VALIDATION
-- Grid search for cross-validation strategy optimization
-- Focus: CV methods, fold counts, test sizes, step-ahead horizons

-- INSTRUCTIONS:
-- 1. Run uaf_data_preparation.sql first to prepare CV splits
-- 2. Configure CV strategy parameters
-- 3. Evaluate overfitting detection capability
-- 4. Select optimal CV configuration for model validation

-- ============================================================================
-- STEP 1: Cross-Validation Parameter Grid
-- ============================================================================

DROP TABLE IF EXISTS cv_param_grid;
CREATE MULTISET TABLE cv_param_grid (
    cv_config_id INTEGER,
    cv_method VARCHAR(50),
    n_folds INTEGER,
    test_size_pct DECIMAL(5,2),
    step_ahead INTEGER,
    min_train_size INTEGER,
    gap_periods INTEGER
);

INSERT INTO cv_param_grid VALUES
    -- K-Fold Cross-Validation
    (1, 'k_fold', 3, 30.0, 1, 50, 0),
    (2, 'k_fold', 5, 20.0, 1, 50, 0),
    (3, 'k_fold', 10, 10.0, 1, 50, 0),

    -- Time Series Split (Rolling Origin)
    (4, 'time_series_split', 5, 20.0, 1, 100, 0),
    (5, 'time_series_split', 5, 20.0, 3, 100, 0),
    (6, 'time_series_split', 5, 20.0, 5, 100, 0),
    (7, 'time_series_split', 10, 10.0, 1, 100, 0),

    -- Blocked Cross-Validation (temporal independence)
    (8, 'blocked_cv', 5, 20.0, 1, 50, 10),
    (9, 'blocked_cv', 5, 20.0, 1, 50, 20),
    (10, 'blocked_cv', 10, 10.0, 1, 50, 10),

    -- Expanding Window
    (11, 'expanding_window', 5, 20.0, 1, 100, 0),
    (12, 'expanding_window', 5, 10.0, 1, 150, 0),
    (13, 'expanding_window', 10, 10.0, 1, 100, 0),

    -- Sliding Window (fixed train size)
    (14, 'sliding_window', 5, 20.0, 1, 200, 0),
    (15, 'sliding_window', 5, 20.0, 3, 200, 0);

-- ============================================================================
-- STEP 2: CV Performance Metrics Template
-- ============================================================================

DROP TABLE IF EXISTS cv_optimization_results;
CREATE MULTISET TABLE cv_optimization_results (
    cv_config_id INTEGER,
    cv_method VARCHAR(50),
    n_folds INTEGER,
    test_size_pct DECIMAL(5,2),
    step_ahead INTEGER,
    -- Cross-validation metrics
    mean_cv_rmse DECIMAL(18,6),
    std_cv_rmse DECIMAL(18,6),
    mean_cv_mae DECIMAL(18,6),
    std_cv_mae DECIMAL(18,6),
    mean_cv_r2 DECIMAL(18,6),
    std_cv_r2 DECIMAL(18,6),
    -- Overfitting detection metrics
    train_test_gap DECIMAL(18,6),
    fold_variance DECIMAL(18,6),
    overfitting_detected INTEGER,
    -- Robustness metrics
    stability_score DECIMAL(10,6),
    consistency_score DECIMAL(10,6),
    -- Computational metrics
    total_folds_executed INTEGER,
    avg_fold_time_sec DECIMAL(10,2),
    total_cv_time_sec DECIMAL(10,2),
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 3: Simulate CV Execution for Each Configuration
-- ============================================================================

INSERT INTO cv_optimization_results
SELECT
    p.cv_config_id,
    p.cv_method,
    p.n_folds,
    p.test_size_pct,
    p.step_ahead,
    -- Simulated CV metrics (replace with actual TD_CROSS_VALIDATION results)
    0.15 + (p.n_folds * 0.005) + (RANDOM() * 0.03) as mean_cv_rmse,
    0.02 + (p.n_folds * 0.002) + (RANDOM() * 0.01) as std_cv_rmse,
    0.12 + (p.n_folds * 0.004) + (RANDOM() * 0.02) as mean_cv_mae,
    0.015 + (p.n_folds * 0.001) + (RANDOM() * 0.008) as std_cv_mae,
    0.85 - (p.n_folds * 0.01) + (RANDOM() * 0.05) as mean_cv_r2,
    0.03 + (p.n_folds * 0.003) + (RANDOM() * 0.01) as std_cv_r2,
    -- Overfitting indicators
    0.05 + (p.n_folds * 0.003) + (RANDOM() * 0.02) as train_test_gap,
    0.02 + (p.n_folds * 0.002) + (RANDOM() * 0.01) as fold_variance,
    CASE WHEN (0.05 + (p.n_folds * 0.003)) > 0.08 THEN 1 ELSE 0 END as overfitting_detected,
    -- Robustness
    0.90 - (p.n_folds * 0.01) + (RANDOM() * 0.05) as stability_score,
    0.88 - (p.n_folds * 0.008) + (RANDOM() * 0.04) as consistency_score,
    -- Computational
    p.n_folds as total_folds_executed,
    5.0 + (p.n_folds * 2.0) + (RANDOM() * 3.0) as avg_fold_time_sec,
    (5.0 + (p.n_folds * 2.0)) * p.n_folds as total_cv_time_sec,
    CURRENT_TIMESTAMP
FROM cv_param_grid p;

-- ============================================================================
-- STEP 4: CV Method Comparison
-- ============================================================================

SELECT
    'CV Method Comparison' as AnalysisType,
    cv_method,
    AVG(mean_cv_rmse) as AvgRMSE,
    AVG(std_cv_rmse) as AvgStdRMSE,
    AVG(train_test_gap) as AvgOverfittingGap,
    AVG(stability_score) as AvgStability,
    AVG(total_cv_time_sec) as AvgTimeSec,
    COUNT(*) as ConfigCount
FROM cv_optimization_results
GROUP BY cv_method
ORDER BY AvgRMSE ASC;

-- ============================================================================
-- STEP 5: Fold Count Impact Analysis
-- ============================================================================

SELECT
    'Fold Count Impact' as AnalysisType,
    n_folds,
    AVG(mean_cv_rmse) as AvgRMSE,
    AVG(std_cv_rmse) as AvgStdRMSE,
    AVG(fold_variance) as AvgFoldVariance,
    AVG(stability_score) as AvgStability,
    AVG(total_cv_time_sec) as AvgTimeSec,
    -- Efficiency: accuracy per unit time
    AVG(stability_score) / NULLIFZERO(AVG(total_cv_time_sec)) as EfficiencyScore
FROM cv_optimization_results
GROUP BY n_folds
ORDER BY n_folds;

-- ============================================================================
-- STEP 6: Overfitting Detection Capability
-- ============================================================================

SELECT
    'Overfitting Detection Analysis' as AnalysisType,
    cv_method,
    n_folds,
    SUM(overfitting_detected) as OverfittingCasesDetected,
    AVG(train_test_gap) as AvgTrainTestGap,
    AVG(fold_variance) as AvgFoldVariance,
    CASE
        WHEN AVG(train_test_gap) > 0.10 THEN 'High Sensitivity'
        WHEN AVG(train_test_gap) > 0.05 THEN 'Moderate Sensitivity'
        ELSE 'Low Sensitivity'
    END as OverfittingDetectionCapability
FROM cv_optimization_results
GROUP BY cv_method, n_folds
ORDER BY AvgTrainTestGap DESC;

-- ============================================================================
-- STEP 7: Stability and Consistency Analysis
-- ============================================================================

SELECT
    'Stability Analysis' as AnalysisType,
    cv_config_id,
    cv_method,
    n_folds,
    CAST(stability_score AS DECIMAL(6,4)) as Stability,
    CAST(consistency_score AS DECIMAL(6,4)) as Consistency,
    CAST(std_cv_rmse / NULLIFZERO(mean_cv_rmse) AS DECIMAL(6,4)) as RMSE_CoeffVariation,
    CASE
        WHEN stability_score > 0.90 AND consistency_score > 0.90 THEN 'Highly Stable'
        WHEN stability_score > 0.80 AND consistency_score > 0.80 THEN 'Stable'
        ELSE 'Unstable'
    END as StabilityAssessment
FROM cv_optimization_results
ORDER BY stability_score DESC;

-- ============================================================================
-- STEP 8: Step-Ahead Forecast Horizon Impact
-- ============================================================================

SELECT
    'Step-Ahead Impact' as AnalysisType,
    step_ahead,
    AVG(mean_cv_rmse) as AvgRMSE,
    AVG(std_cv_rmse) as AvgStdRMSE,
    AVG(mean_cv_mae) as AvgMAE,
    -- Forecast horizon difficulty (error increase per step)
    (MAX(mean_cv_rmse) - MIN(mean_cv_rmse)) / NULLIFZERO(MAX(step_ahead) - MIN(step_ahead)) as ErrorIncreasePerStep
FROM cv_optimization_results
WHERE cv_method = 'time_series_split'
GROUP BY step_ahead
ORDER BY step_ahead;

-- ============================================================================
-- STEP 9: Composite CV Quality Score
-- ============================================================================

DROP TABLE IF EXISTS cv_quality_scores;
CREATE MULTISET TABLE cv_quality_scores AS (
    SELECT
        cv_config_id,
        cv_method,
        n_folds,
        -- Normalize metrics (lower is better for errors, higher is better for stability)
        (1.0 - (mean_cv_rmse - min_rmse) / NULLIFZERO(max_rmse - min_rmse)) as rmse_score,
        (1.0 - (std_cv_rmse - min_std) / NULLIFZERO(max_std - min_std)) as consistency_score,
        stability_score as stability_score,
        (1.0 - (train_test_gap - min_gap) / NULLIFZERO(max_gap - min_gap)) as overfitting_control_score,
        (1.0 - (total_cv_time_sec - min_time) / NULLIFZERO(max_time - min_time)) as efficiency_score,
        -- Composite score
        (1.0 - (mean_cv_rmse - min_rmse) / NULLIFZERO(max_rmse - min_rmse)) * 0.30 +
        (1.0 - (std_cv_rmse - min_std) / NULLIFZERO(max_std - min_std)) * 0.20 +
        stability_score * 0.25 +
        (1.0 - (train_test_gap - min_gap) / NULLIFZERO(max_gap - min_gap)) * 0.15 +
        (1.0 - (total_cv_time_sec - min_time) / NULLIFZERO(max_time - min_time)) * 0.10 as total_cv_quality_score
    FROM cv_optimization_results
    CROSS JOIN (
        SELECT
            MIN(mean_cv_rmse) as min_rmse, MAX(mean_cv_rmse) as max_rmse,
            MIN(std_cv_rmse) as min_std, MAX(std_cv_rmse) as max_std,
            MIN(train_test_gap) as min_gap, MAX(train_test_gap) as max_gap,
            MIN(total_cv_time_sec) as min_time, MAX(total_cv_time_sec) as max_time
        FROM cv_optimization_results
    ) ranges
) WITH DATA;

-- ============================================================================
-- STEP 10: Optimal CV Configuration Selection
-- ============================================================================

SELECT
    'Top CV Configurations' as ReportType,
    r.cv_config_id,
    r.cv_method,
    r.n_folds,
    r.test_size_pct,
    r.step_ahead,
    CAST(q.total_cv_quality_score AS DECIMAL(6,4)) as QualityScore,
    CAST(r.mean_cv_rmse AS DECIMAL(10,6)) as CV_RMSE,
    CAST(r.stability_score AS DECIMAL(6,4)) as Stability,
    CAST(r.train_test_gap AS DECIMAL(10,6)) as OverfittingGap,
    CAST(r.total_cv_time_sec AS DECIMAL(8,2)) as TimeSec,
    RANK() OVER (ORDER BY q.total_cv_quality_score DESC) as Rank
FROM cv_quality_scores q
INNER JOIN cv_optimization_results r ON q.cv_config_id = r.cv_config_id
ORDER BY q.total_cv_quality_score DESC
FETCH FIRST 5 ROWS ONLY;

-- Best CV configuration
SELECT
    'OPTIMAL CV CONFIGURATION' as ConfigType,
    r.cv_method as RecommendedMethod,
    r.n_folds as RecommendedFolds,
    r.test_size_pct as RecommendedTestSize,
    r.step_ahead as RecommendedStepAhead,
    CAST(q.total_cv_quality_score AS DECIMAL(6,4)) as QualityScore,
    CAST(r.mean_cv_rmse AS DECIMAL(10,6)) as ExpectedCV_RMSE,
    CAST(r.stability_score AS DECIMAL(6,4)) as ExpectedStability
FROM cv_quality_scores q
INNER JOIN cv_optimization_results r ON q.cv_config_id = r.cv_config_id
ORDER BY q.total_cv_quality_score DESC
FETCH FIRST 1 ROW ONLY;

-- Export optimal configuration
DROP TABLE IF EXISTS optimal_cv_config;
CREATE MULTISET TABLE optimal_cv_config AS (
    SELECT
        r.*,
        q.total_cv_quality_score,
        'PRODUCTION' as config_status,
        CURRENT_TIMESTAMP as config_timestamp
    FROM cv_quality_scores q
    INNER JOIN cv_optimization_results r ON q.cv_config_id = r.cv_config_id
    ORDER BY q.total_cv_quality_score DESC
    FETCH FIRST 1 ROW ONLY
) WITH DATA;

SELECT * FROM optimal_cv_config;

/*
CROSS-VALIDATION OPTIMIZATION CHECKLIST:
□ Test multiple CV strategies (k-fold, time series split, blocked, expanding)
□ Evaluate fold count impact (3, 5, 10 folds)
□ Assess test size percentage (10%, 20%, 30%)
□ Configure step-ahead forecast horizons
□ Measure overfitting detection capability
□ Evaluate stability and consistency
□ Consider computational efficiency
□ Select optimal CV configuration

CV METHOD RECOMMENDATIONS:
- K-Fold: Use cautiously with time series (may violate temporal ordering)
- Time Series Split: Best for forecasting (respects temporal structure)
- Blocked CV: Reduces temporal correlation, prevents data leakage
- Expanding Window: Most realistic for operational forecasting
- Sliding Window: Fixed train size, good for non-stationary series

QUALITY SCORE WEIGHTS:
- CV RMSE: 30% (prediction accuracy)
- Consistency (low variance): 20% (fold stability)
- Stability Score: 25% (robustness)
- Overfitting Control: 15% (generalization capability)
- Efficiency: 10% (computational cost)

NEXT STEPS:
1. Review optimal CV configuration
2. Validate on multiple models
3. Assess overfitting detection capability
4. Apply optimal CV strategy to model validation
5. Monitor CV performance over time
6. Use optimal_cv_config in td_cross_validation_workflow.sql
*/
