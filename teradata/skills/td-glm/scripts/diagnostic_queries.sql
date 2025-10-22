-- =====================================================
-- Diagnostic Queries - Model Interpretation & Validation
-- =====================================================
-- Purpose: Analyze GLM performance, coefficients, and diagnostics
-- Focus: Coefficient analysis, residual analysis, model assumptions
-- =====================================================

-- =====================================================
-- 1. MODEL COEFFICIENTS ANALYSIS
-- =====================================================

-- Extract and interpret model coefficients
SELECT
    predictor as feature_name,
    estimate as coefficient_value,
    std_error as standard_error,
    z_score,
    p_value,
    ABS(estimate) as abs_coefficient,
    RANK() OVER (ORDER BY ABS(estimate) DESC) as importance_rank,
    CASE
        WHEN estimate > 0 THEN 'Positive Impact'
        WHEN estimate < 0 THEN 'Negative Impact'
        ELSE 'No Impact'
    END as direction_of_effect,
    CASE
        WHEN p_value < 0.001 THEN '***'
        WHEN p_value < 0.01 THEN '**'
        WHEN p_value < 0.05 THEN '*'
        WHEN p_value < 0.10 THEN '.'
        ELSE 'Not Significant'
    END as significance_level
FROM {database}.glm_model_out
WHERE predictor <> 'Intercept'
ORDER BY ABS(estimate) DESC;

-- View intercept separately
SELECT
    predictor as parameter,
    estimate as value,
    std_error,
    z_score,
    p_value,
    'Baseline prediction when all features = 0' as interpretation
FROM {database}.glm_model_out
WHERE predictor = 'Intercept';

-- Feature significance summary
SELECT
    COUNT(*) as total_features,
    SUM(CASE WHEN p_value < 0.05 THEN 1 ELSE 0 END) as significant_features,
    SUM(CASE WHEN p_value >= 0.05 THEN 1 ELSE 0 END) as non_significant_features,
    SUM(CASE WHEN estimate > 0 THEN 1 ELSE 0 END) as positive_features,
    SUM(CASE WHEN estimate < 0 THEN 1 ELSE 0 END) as negative_features,
    MAX(ABS(estimate)) as max_abs_coefficient,
    AVG(ABS(estimate)) as avg_abs_coefficient
FROM {database}.glm_model_out
WHERE predictor <> 'Intercept';

-- =====================================================
-- 2. MODEL FIT STATISTICS
-- =====================================================

-- Extract model fit statistics (if available from model output)
SELECT
    'Model Fit Statistics' as metric_type,
    deviance,
    null_deviance,
    aic,
    (null_deviance - deviance) as deviance_reduction,
    CAST((null_deviance - deviance) / null_deviance * 100 AS DECIMAL(5,2)) as percent_deviance_explained
FROM {database}.glm_model_out
WHERE predictor = 'Model_Statistics';

-- =====================================================
-- 3. RESIDUAL ANALYSIS
-- =====================================================

-- Calculate residuals for predictions
DROP TABLE IF EXISTS {database}.residuals_analysis;
CREATE MULTISET TABLE {database}.residuals_analysis AS (
    SELECT
        {id_column},
        {target_column} as actual,
        prediction as predicted,
        (prediction - {target_column}) as residual,
        ABS(prediction - {target_column}) as absolute_residual,
        POWER(prediction - {target_column}, 2) as squared_residual,
        -- Standardized residual
        (prediction - {target_column}) / STDDEV(prediction - {target_column}) OVER() as standardized_residual,
        -- Deviance residual (simplified for Gaussian)
        SIGN(prediction - {target_column}) * SQRT(2 * ABS(prediction - {target_column})) as deviance_residual,
        -- Percentage error
        CASE
            WHEN {target_column} <> 0 THEN
                ABS((prediction - {target_column}) / {target_column}) * 100
            ELSE NULL
        END as percentage_error
    FROM {database}.predictions_out
) WITH DATA;

-- Residual summary statistics
SELECT
    COUNT(*) as n_observations,
    AVG(residual) as mean_residual,
    STDDEV(residual) as std_residual,
    MIN(residual) as min_residual,
    MAX(residual) as max_residual,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY residual) as q1_residual,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY residual) as median_residual,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY residual) as q3_residual,
    AVG(deviance_residual) as mean_deviance_residual,
    -- Check for zero mean (good model should have ~0)
    CASE
        WHEN ABS(AVG(residual)) < 0.01 * STDDEV(residual) THEN 'PASS - Mean Near Zero'
        ELSE 'WARNING - Non-Zero Mean'
    END as mean_check
FROM {database}.residuals_analysis;

-- Residual distribution (histogram bins)
SELECT
    CASE
        WHEN standardized_residual < -3 THEN '< -3 (Extreme)'
        WHEN standardized_residual < -2 THEN '-3 to -2'
        WHEN standardized_residual < -1 THEN '-2 to -1'
        WHEN standardized_residual < 0 THEN '-1 to 0'
        WHEN standardized_residual < 1 THEN '0 to 1'
        WHEN standardized_residual < 2 THEN '1 to 2'
        WHEN standardized_residual < 3 THEN '2 to 3'
        ELSE '> 3 (Extreme)'
    END as residual_bin,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    RPAD('*', CAST(COUNT(*) * 50.0 / MAX(COUNT(*)) OVER() AS INTEGER), '*') as visual_bar
FROM {database}.residuals_analysis
GROUP BY 1
ORDER BY
    CASE
        WHEN standardized_residual < -3 THEN 1
        WHEN standardized_residual < -2 THEN 2
        WHEN standardized_residual < -1 THEN 3
        WHEN standardized_residual < 0 THEN 4
        WHEN standardized_residual < 1 THEN 5
        WHEN standardized_residual < 2 THEN 6
        WHEN standardized_residual < 3 THEN 7
        ELSE 8
    END;

-- =====================================================
-- 4. OUTLIER AND INFLUENTIAL POINTS DETECTION
-- =====================================================

-- Identify observations with large residuals
SELECT
    {id_column},
    actual,
    predicted,
    residual,
    standardized_residual,
    deviance_residual,
    CASE
        WHEN ABS(standardized_residual) > 3 THEN 'Extreme Outlier'
        WHEN ABS(standardized_residual) > 2 THEN 'Moderate Outlier'
        ELSE 'Normal'
    END as outlier_classification
FROM {database}.residuals_analysis
WHERE ABS(standardized_residual) > 2
ORDER BY ABS(standardized_residual) DESC;

-- Outlier summary
SELECT
    SUM(CASE WHEN ABS(standardized_residual) > 3 THEN 1 ELSE 0 END) as extreme_outliers,
    SUM(CASE WHEN ABS(standardized_residual) > 2 THEN 1 ELSE 0 END) as moderate_outliers,
    COUNT(*) as total_observations,
    CAST(SUM(CASE WHEN ABS(standardized_residual) > 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as extreme_outlier_pct,
    CASE
        WHEN SUM(CASE WHEN ABS(standardized_residual) > 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) < 1 THEN 'PASS'
        ELSE 'WARNING - High Outlier Rate'
    END as outlier_check
FROM {database}.residuals_analysis;

-- =====================================================
-- 5. HOMOSCEDASTICITY CHECK (Constant Variance)
-- =====================================================

-- Check if residual variance changes with predicted values
WITH prediction_bins AS (
    SELECT
        NTILE(10) OVER (ORDER BY predicted) as bin_number,
        predicted,
        residual,
        squared_residual
    FROM {database}.residuals_analysis
)
SELECT
    bin_number,
    COUNT(*) as n_observations,
    MIN(predicted) as min_predicted,
    MAX(predicted) as max_predicted,
    AVG(predicted) as avg_predicted,
    AVG(residual) as avg_residual,
    STDDEV(residual) as std_residual,
    SQRT(AVG(squared_residual)) as rmse_in_bin
FROM prediction_bins
GROUP BY bin_number
ORDER BY bin_number;

-- Statistical test for heteroscedasticity
WITH variance_test AS (
    SELECT
        CASE
            WHEN predicted <= PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY predicted) OVER()
            THEN 'Lower Half'
            ELSE 'Upper Half'
        END as prediction_group,
        residual
    FROM {database}.residuals_analysis
)
SELECT
    prediction_group,
    COUNT(*) as n,
    VARIANCE(residual) as variance,
    STDDEV(residual) as std_dev,
    MAX(VARIANCE(residual)) OVER() / MIN(VARIANCE(residual)) OVER() as variance_ratio,
    CASE
        WHEN MAX(VARIANCE(residual)) OVER() / MIN(VARIANCE(residual)) OVER() < 2 THEN 'PASS - Homoscedastic'
        WHEN MAX(VARIANCE(residual)) OVER() / MIN(VARIANCE(residual)) OVER() < 4 THEN 'WARNING - Possible Heteroscedasticity'
        ELSE 'FAIL - Heteroscedastic'
    END as homoscedasticity_check
FROM variance_test
GROUP BY prediction_group;

-- =====================================================
-- 6. LINEARITY ASSUMPTION CHECK
-- =====================================================

-- Check for non-linear patterns in residuals vs predicted
WITH prediction_bins AS (
    SELECT
        NTILE(10) OVER (ORDER BY predicted) as bin,
        predicted,
        residual
    FROM {database}.residuals_analysis
)
SELECT
    bin,
    COUNT(*) as n,
    AVG(predicted) as avg_predicted,
    AVG(residual) as avg_residual,
    STDDEV(residual) as std_residual,
    -- Check if mean residual is close to zero in each bin
    CASE
        WHEN ABS(AVG(residual)) < STDDEV(residual) / SQRT(COUNT(*)) THEN 'PASS'
        ELSE 'WARNING - Possible Non-Linearity'
    END as linearity_check
FROM prediction_bins
GROUP BY bin
ORDER BY bin;

-- =====================================================
-- 7. NORMALITY OF RESIDUALS (For Gaussian GLM)
-- =====================================================

-- Calculate skewness and kurtosis
WITH residual_moments AS (
    SELECT
        AVG(residual) as mean_r,
        STDDEV(residual) as std_r,
        COUNT(*) as n
    FROM {database}.residuals_analysis
),
standardized_moments AS (
    SELECT
        r.residual,
        (r.residual - m.mean_r) / NULLIF(m.std_r, 0) as z_residual,
        POWER((r.residual - m.mean_r) / NULLIF(m.std_r, 0), 3) as z_cubed,
        POWER((r.residual - m.mean_r) / NULLIF(m.std_r, 0), 4) as z_fourth
    FROM {database}.residuals_analysis r, residual_moments m
)
SELECT
    AVG(z_cubed) as skewness,
    AVG(z_fourth) - 3 as excess_kurtosis,
    CASE
        WHEN ABS(AVG(z_cubed)) < 0.5 THEN 'PASS - Near Normal'
        WHEN ABS(AVG(z_cubed)) < 1.0 THEN 'WARNING - Moderate Skew'
        ELSE 'FAIL - High Skew'
    END as normality_check_skew,
    CASE
        WHEN ABS(AVG(z_fourth) - 3) < 1.0 THEN 'PASS - Near Normal'
        WHEN ABS(AVG(z_fourth) - 3) < 2.0 THEN 'WARNING - Moderate Kurtosis'
        ELSE 'FAIL - High Kurtosis'
    END as normality_check_kurtosis
FROM standardized_moments;

-- =====================================================
-- 8. PREDICTION ERROR BY TARGET RANGE
-- =====================================================

-- Analyze how error varies across different target value ranges
SELECT
    CASE
        WHEN {target_column} <= PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 'Very Low (0-20%)'
        WHEN {target_column} <= PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 'Low (20-40%)'
        WHEN {target_column} <= PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 'Medium (40-60%)'
        WHEN {target_column} <= PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 'High (60-80%)'
        ELSE 'Very High (80-100%)'
    END as target_range,
    COUNT(*) as n_observations,
    AVG({target_column}) as avg_actual,
    AVG(prediction) as avg_predicted,
    SQRT(AVG(POWER(prediction - {target_column}, 2))) as rmse,
    AVG(ABS(prediction - {target_column})) as mae,
    AVG(percentage_error) as mape
FROM {database}.residuals_analysis
GROUP BY 1
ORDER BY
    CASE
        WHEN {target_column} <= PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 1
        WHEN {target_column} <= PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 2
        WHEN {target_column} <= PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 3
        WHEN {target_column} <= PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 4
        ELSE 5
    END;

-- =====================================================
-- 9. MODEL DIAGNOSTICS SUMMARY REPORT
-- =====================================================

-- Comprehensive diagnostic report
SELECT
    'GLM Diagnostics Summary' as report_type,
    (SELECT COUNT(*) FROM {database}.predictions_out) as total_predictions,
    (SELECT CAST(AVG(residual) AS DECIMAL(10,6)) FROM {database}.residuals_analysis) as mean_residual,
    (SELECT CAST(STDDEV(residual) AS DECIMAL(10,4)) FROM {database}.residuals_analysis) as std_residual,
    (SELECT CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.residuals_analysis) AS DECIMAL(5,2))
     FROM {database}.residuals_analysis
     WHERE ABS(standardized_residual) > 3) as extreme_outlier_pct,
    (SELECT COUNT(*)
     FROM {database}.glm_model_out
     WHERE predictor <> 'Intercept' AND p_value < 0.05) as significant_features,
    (SELECT COUNT(*)
     FROM {database}.glm_model_out
     WHERE predictor <> 'Intercept') as total_features;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {target_column} - Target variable
--    {id_column} - Unique identifier
--
-- 2. Diagnostic workflow:
--    a. Examine model coefficients and significance
--    b. Review model fit statistics (deviance, AIC)
--    c. Analyze residual distribution and patterns
--    d. Identify outliers and influential points
--    e. Check GLM assumptions (homoscedasticity, linearity)
--    f. Assess normality of residuals (for Gaussian family)
--    g. Evaluate performance across target ranges
--    h. Generate comprehensive diagnostic report
--
-- 3. Interpreting results:
--    - Significant features: p-value < 0.05
--    - Mean residual should be near zero
--    - Standardized residuals mostly within [-2, 2]
--    - Deviance reduction indicates model improvement
--    - AIC: Lower is better (for model comparison)
--
-- =====================================================
