# Teradata ClearScape Analytics Skills

This repository provides a comprehensive collection of production-ready skills for Teradata ClearScape Analytics functions, following the Anthropic Claude Skills format. These skills enable AI assistants to help users leverage the full power of Teradata's advanced analytics capabilities.

## Overview

- **Total Skills**: 53
- **Platform**: Teradata Vantage with ClearScape Analytics
- **Format**: Claude Code Skills
- **Coverage**: Machine Learning, Time Series, Signal Processing, Text Analytics, and Advanced Analytics

## Quick Start

Each skill folder contains:
- `SKILL.md` - Complete skill documentation and instructions
- `scripts/` - SQL scripts for implementation including table analysis
- `resources/` - Configuration files and templates

## Requirements

- Teradata Vantage with ClearScape Analytics enabled
- Appropriate database permissions
- Access to specified analytical functions

---

## Skills by Category

### 1. Data Quality & Profiling (1 skill)

- **[Teradata Data Profiling](./teradata/skills/td-data-profiling/SKILL.md)**: Comprehensive data profiling and quality assessment using descriptive statistics functions

### 2. Data Preprocessing & Transformation (6 skills)

- **[Teradata UAF Data Preparation](./teradata/skills/td-data-preparation/SKILL.md)**: UAF-specific data preparation and validation for time series analysis
- **[Teradata Data Scaling Suite](./teradata/skills/td-scale-fit/SKILL.md)**: Data scaling and normalization using TD_ScaleFit and TD_ScaleTransform
- **[Teradata One-Hot Encoding Suite](./teradata/skills/td-onehot-encoding/SKILL.md)**: Categorical variable encoding using TD_OneHotEncodingFit and Transform
- **[Teradata Column Transformer](./teradata/skills/td-column-transformer/SKILL.md)**: Advanced column transformation and feature engineering
- **[Teradata Simple Imputation](./teradata/skills/td-simple-impute/SKILL.md)**: Missing value imputation using TD_SimpleImputeFit
- **[Teradata Train-Test Split](./teradata/skills/td-train-test-split/SKILL.md)**: Data splitting for model validation using TD_TrainTestSplit

### 3. Regression Models (3 skills)

- **[Teradata GLM Analytics](./teradata/skills/td-glm/SKILL.md)**: Comprehensive Generalized Linear Model analytics for regression and classification
- **[Teradata Linear Regression](./teradata/skills/td-linear-regression/SKILL.md)**: Linear regression analysis for continuous target prediction
- **[Teradata Logistic Regression](./teradata/skills/td-logistic-regression/SKILL.md)**: Logistic regression for binary and multinomial classification

### 4. Classification Models (5 skills)

- **[Teradata Decision Tree Analytics](./teradata/skills/td-decision-tree/SKILL.md)**: Decision tree classifier for categorical prediction and rule extraction
- **[Teradata Decision Forest Analytics](./teradata/skills/td-decision-forest/SKILL.md)**: Decision forest ensemble classifier for robust predictions
- **[Teradata Random Forest Analytics](./teradata/skills/td-random-forest/SKILL.md)**: Random forest ensemble classifier for high-accuracy classification
- **[Teradata Support Vector Machine](./teradata/skills/td-svm/SKILL.md)**: Support Vector Machine for linear and non-linear classification
- **[Teradata Naive Bayes Classifier](./teradata/skills/td-naive-bayes/SKILL.md)**: Naive Bayes classifier for probabilistic classification

### 5. Clustering (2 skills)

- **[Teradata K-Means Clustering](./teradata/skills/td-kmeans/SKILL.md)**: K-means clustering for customer segmentation and data grouping
- **[Teradata Hierarchical Clustering](./teradata/skills/td-hierarchical-clustering/SKILL.md)**: Hierarchical clustering for nested data grouping

### 6. Model Evaluation & Selection (4 skills)

- **[Teradata Regression Evaluation Suite](./teradata/skills/td-regression-evaluator/SKILL.md)**: Comprehensive regression model evaluation using TD_RegressionEvaluator
- **[Teradata Classification Evaluation Suite](./teradata/skills/td-classification-evaluator/SKILL.md)**: Classification model evaluation and metrics calculation
- **[Teradata Time Series Cross-Validation](./teradata/skills/td-cross-validation/SKILL.md)**: Time series specific cross-validation techniques for model validation
- **[Teradata Automated Model Selection](./teradata/skills/td-model-selection/SKILL.md)**: Automated model selection and comparison for optimal forecasting

### 7. Text Analytics (3 skills)

- **[Teradata TF-IDF Text Analytics](./teradata/skills/td-tfidf/SKILL.md)**: Term Frequency-Inverse Document Frequency for text analysis
- **[Teradata N-Gram Splitter](./teradata/skills/td-ngram-splitter/SKILL.md)**: N-gram generation for text preprocessing
- **[Teradata Vector Distance Analytics](./teradata/skills/td-vector-distance/SKILL.md)**: Vector distance calculations for similarity analysis

### 8. Time Series - ARIMA & Forecasting (4 skills)

- **[Teradata ARIMA Time Series](./teradata/skills/td-arima/SKILL.md)**: ARIMA modeling for time series forecasting
- **[Teradata ARIMA Parameter Estimation](./teradata/skills/td-arimaestimate/SKILL.md)**: ARIMA parameter estimation for seasonal and non-seasonal models
- **[Teradata ARIMA Forecasting](./teradata/skills/td-arima-forecast/SKILL.md)**: ARIMA-based time series forecasting for trend and seasonal predictions
- **[Teradata Moving Average Forecasting](./teradata/skills/td-movavg-forecast/SKILL.md)**: Moving average based forecasting for smoothed predictions

### 9. Time Series - Autocorrelation & Diagnostics (3 skills)

- **[Teradata Auto-Correlation Function](./teradata/skills/td-acf/SKILL.md)**: Auto-correlation analysis for time series dependency and pattern detection
- **[Teradata Partial Auto-Correlation Function](./teradata/skills/td-pacf/SKILL.md)**: Partial auto-correlation analysis for direct lag relationships
- **[Teradata Ljung-Box Test](./teradata/skills/td-portman/SKILL.md)**: Ljung-Box portmanteau tests for model diagnostics and residual analysis

### 10. Time Series - Decomposition & Transformation (4 skills)

- **[Teradata Seasonal Decomposition](./teradata/skills/td-seasonal-decompose/SKILL.md)**: Seasonal pattern decomposition and analysis
- **[Teradata Time Series Differencing](./teradata/skills/td-diff/SKILL.md)**: Time series differencing for stationarity and trend removal
- **[Teradata Signal Detrending](./teradata/skills/td-detrend/SKILL.md)**: Signal detrending for baseline correction and trend removal
- **[Teradata Stationarity Testing](./teradata/skills/td-stationarity-test/SKILL.md)**: Statistical tests for time series stationarity (ADF, KPSS, PP tests)

### 11. Digital Signal Processing - Fourier Transforms (3 skills)

- **[Teradata Fast Fourier Transform](./teradata/skills/td-fft/SKILL.md)**: Fast Fourier Transform for frequency domain analysis and spectral decomposition
- **[Teradata Inverse Fast Fourier Transform](./teradata/skills/td-ifft/SKILL.md)**: Inverse Fast Fourier Transform for time domain reconstruction
- **[Teradata Discrete Fourier Transform](./teradata/skills/td-dfft/SKILL.md)**: Discrete Fourier transformation for frequency domain analysis

### 12. Digital Signal Processing - Filtering & Processing (6 skills)

- **[Teradata Digital Signal Filtering](./teradata/skills/td-filter/SKILL.md)**: Digital filtering for noise reduction and signal enhancement
- **[Teradata Windowing Functions](./teradata/skills/td-window/SKILL.md)**: Signal windowing for spectral analysis and leakage reduction
- **[Teradata Signal Convolution](./teradata/skills/td-convolution/SKILL.md)**: Convolution operations for signal processing and filtering
- **[Teradata Signal Correlation](./teradata/skills/td-correlation/SKILL.md)**: Signal correlation analysis for similarity and delay detection
- **[Teradata Signal Resampling](./teradata/skills/td-resample/SKILL.md)**: Signal resampling and interpolation for rate conversion
- **[Teradata Signal Smoothing](./teradata/skills/td-smoothing/SKILL.md)**: Signal smoothing and noise reduction techniques

### 13. Spectral Analysis & Visualization (3 skills)

- **[Teradata Power Spectral Density](./teradata/skills/td-powerspec/SKILL.md)**: Power spectrum analysis for frequency domain insights and periodicity detection
- **[Teradata Spectral Density Analysis](./teradata/skills/td-spectral-density/SKILL.md)**: Power spectral density estimation for frequency content analysis
- **[Teradata Time Series Plotting](./teradata/skills/td-plot/SKILL.md)**: Time series visualization and diagnostic plotting utilities

### 14. Advanced Analytics & Pattern Detection (5 skills)

- **[Teradata Sessionization Analytics](./teradata/skills/td-sessionize/SKILL.md)**: Session analysis and user journey tracking
- **[Teradata nPath Analytics](./teradata/skills/td-npath/SKILL.md)**: Path analysis for sequential event patterns
- **[Teradata Attribution Analytics](./teradata/skills/td-attribution/SKILL.md)**: Marketing attribution modeling and analysis
- **[Teradata Outlier Detection](./teradata/skills/td-outlier-detection/SKILL.md)**: Outlier detection and handling using TD_OutlierFit
- **[Teradata Change Point Detection](./teradata/skills/td-change-point/SKILL.md)**: Change point detection in time series for structural breaks

### 15. Parameter Estimation (1 skill)

- **[Teradata Parameter Estimation Suite](./teradata/skills/td-parameter-estimation/SKILL.md)**: Advanced parameter estimation and optimization for UAF models

---

## Key Capabilities by Domain

### Machine Learning
- **Supervised Learning**: Regression (Linear, Logistic, GLM), Classification (Trees, Forests, SVM, Naive Bayes)
- **Unsupervised Learning**: Clustering (K-Means, Hierarchical)
- **Model Lifecycle**: Data preparation, feature engineering, training, evaluation, selection
- **Model Validation**: Cross-validation, train-test split, performance metrics

### Time Series Analysis
- **Forecasting**: ARIMA modeling, moving averages, seasonal decomposition
- **Diagnostics**: ACF/PACF analysis, stationarity testing, Ljung-Box tests
- **Transformations**: Differencing, detrending, seasonal adjustment
- **Change Detection**: Structural break identification, anomaly detection

### Digital Signal Processing
- **Frequency Analysis**: FFT, inverse FFT, discrete FFT, spectral density
- **Signal Enhancement**: Filtering, smoothing, windowing, detrending
- **Signal Operations**: Convolution, correlation, resampling
- **Noise Reduction**: Multiple filtering and smoothing techniques

### Text & Natural Language
- **Feature Extraction**: TF-IDF, n-grams
- **Similarity Analysis**: Vector distance calculations
- **Text Preprocessing**: Tokenization, term weighting

### Data Quality & Preparation
- **Profiling**: Comprehensive statistical analysis, distribution analysis
- **Cleaning**: Missing value imputation, outlier detection
- **Transformation**: Scaling, encoding, column transformation
- **Validation**: Data quality metrics, statistical tests

### Advanced Analytics
- **Customer Analytics**: Sessionization, path analysis, attribution
- **Pattern Recognition**: Sequential patterns, event analysis
- **Anomaly Detection**: Outliers, change points, unusual patterns

---

## Industry Applications

### Financial Services
- Fraud detection and anomaly identification
- Credit risk modeling and scoring
- Time series forecasting for market trends
- Customer segmentation and targeting

### Retail & E-Commerce
- Demand forecasting and inventory optimization
- Customer journey analysis and attribution
- Market basket analysis and recommendations
- Sales prediction and trend analysis

### Telecommunications
- Customer churn prediction
- Network traffic analysis and optimization
- Signal processing for quality monitoring
- Usage pattern detection

### Manufacturing & IoT
- Predictive maintenance with sensor data
- Quality control and process monitoring
- Time series analysis for equipment performance
- Signal processing for defect detection

### Healthcare & Life Sciences
- Patient outcome prediction
- Medical signal processing (ECG, EEG analysis)
- Disease progression modeling
- Clinical trial analytics

### Marketing & Digital Analytics
- Campaign attribution and effectiveness
- Customer segmentation and personalization
- Web analytics and user behavior analysis
- A/B testing and experimentation

---

## Unbounded Array Framework (UAF)

Many skills leverage Teradata's UAF for:
- **Scalable time series analysis** for millions of products or billions of sensors
- **End-to-end forecasting pipelines** with integrated preprocessing
- **Digital signal processing** for complex signal analysis
- **4D spatial analytics** and high-dimensional data processing

UAF-specific skills provide:
- Optimized memory and processing for array operations
- Support for regular and irregular time intervals
- Integration across multiple UAF functions
- Performance tuning for large-scale analytics

---

## Best Practices

### Data Preparation
1. Start with data profiling to understand quality and characteristics
2. Handle missing values and outliers appropriately
3. Scale and normalize features for ML models
4. Split data properly for training and validation

### Model Development
1. Select appropriate models based on problem type and data characteristics
2. Use cross-validation for robust model assessment
3. Evaluate models using multiple metrics
4. Compare multiple models before final selection

### Time Series & Signals
1. Test for stationarity before ARIMA modeling
2. Examine ACF/PACF plots for model identification
3. Validate residuals using diagnostic tests
4. Consider seasonal patterns in decomposition

### Production Deployment
1. Document all analytical workflows and parameters
2. Implement proper error handling and validation
3. Monitor data quality and model performance over time
4. Maintain version control for models and scripts

---

## Skill Structure

Each skill follows a standardized format:

```
skill-name/
├── SKILL.md              # Complete documentation and instructions
├── scripts/              # SQL implementation scripts
│   ├── analyze_table.sql
│   ├── main_workflow.sql
│   └── ...
└── resources/            # Configuration and templates
    ├── config.yaml
    └── ...
```

### SKILL.md Contents
- Skill metadata (name, description, category, functions)
- Core capabilities and features
- Detailed workflow explanations
- Input requirements and output formats
- Example usage and SQL code
- Best practices and limitations
- Integration guidance

### Scripts Directory
- Table analysis and validation queries
- Main analytical workflow SQL
- Result interpretation queries
- Cleanup and maintenance scripts

### Resources Directory
- Configuration templates
- Parameter reference files
- Integration examples

---

## Getting Started

1. **Identify Your Use Case**: Browse skills by category to find relevant analytics
2. **Review Requirements**: Ensure you have necessary Teradata functions and permissions
3. **Choose a Skill**: Read the SKILL.md for detailed documentation
4. **Prepare Your Data**: Follow data requirements and run table analysis
5. **Execute Workflow**: Use provided SQL scripts or let Claude generate custom queries
6. **Interpret Results**: Review outputs and apply business context

---

## Technical Requirements

### Platform
- **Teradata Vantage** 17.x or higher
- **ClearScape Analytics** enabled
- **UAF licensing** (for UAF-based skills)

### Permissions
- SELECT on source tables
- CREATE TABLE for intermediate results
- EXECUTE on analytical functions

### Resources
- Adequate temporary space for intermediate results
- Sufficient memory for array processing (UAF skills)
- Appropriate spool space for large datasets

---

## Support & Contribution

These skills are designed to work with Claude Code and other Claude-powered assistants. Each skill provides comprehensive guidance for:
- Understanding analytical techniques
- Preparing appropriate data
- Executing Teradata functions correctly
- Interpreting results in business context
- Troubleshooting common issues

For questions or improvements, please refer to individual SKILL.md files for detailed documentation.

---

*Production-ready analytics skills for the complete Teradata ClearScape Analytics suite, following industry best practices and optimized for AI-assisted data analysis workflows.*
