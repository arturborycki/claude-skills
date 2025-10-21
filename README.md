# Complete Teradata ClearScape Analytics Skills

This collection provides comprehensive analytical skills for the full range of Teradata ClearScape Analytics functions, following the Anthropic Claude Skills format.

## Function Categories

### Regression

- **[Teradata GLM Analytics](./td-glm/SKILL.md)**: Comprehensive Generalized Linear Model analytics for regression and classification
- **[Teradata Linear Regression](./td-linear-regression/SKILL.md)**: Linear regression analysis for continuous target prediction
- **[Teradata Logistic Regression](./td-logistic-regression/SKILL.md)**: Logistic regression for binary and multinomial classification

### Classification

- **[Teradata Decision Tree Analytics](./td-decision-tree/SKILL.md)**: Decision tree classifier for categorical prediction and rule extraction
- **[Teradata Decision Forest Analytics](./td-decision-forest/SKILL.md)**: Decision forest ensemble classifier for robust predictions
- **[Teradata Random Forest Analytics](./td-random-forest/SKILL.md)**: Random forest ensemble classifier for high-accuracy classification
- **[Teradata Support Vector Machine](./td-svm/SKILL.md)**: Support Vector Machine for linear and non-linear classification
- **[Teradata Naive Bayes Classifier](./td-naive-bayes/SKILL.md)**: Naive Bayes classifier for probabilistic classification

### Clustering

- **[Teradata K-Means Clustering](./td-kmeans/SKILL.md)**: K-means clustering for customer segmentation and data grouping
- **[Teradata Hierarchical Clustering](./td-hierarchical-clustering/SKILL.md)**: Hierarchical clustering for nested data grouping

### Preprocessing

- **[Teradata Data Scaling Suite](./td-scale-fit/SKILL.md)**: Data scaling and normalization using TD_ScaleFit and TD_ScaleTransform
- **[Teradata One-Hot Encoding Suite](./td-onehot-encoding/SKILL.md)**: Categorical variable encoding using TD_OneHotEncodingFit and Transform
- **[Teradata Column Transformer](./td-column-transformer/SKILL.md)**: Advanced column transformation and feature engineering
- **[Teradata Simple Imputation](./td-simple-impute/SKILL.md)**: Missing value imputation using TD_SimpleImputeFit
- **[Teradata Outlier Detection](./td-outlier-detection/SKILL.md)**: Outlier detection and handling using TD_OutlierFit
- **[Teradata Train-Test Split](./td-train-test-split/SKILL.md)**: Data splitting for model validation using TD_TrainTestSplit

### Evaluation

- **[Teradata Regression Evaluation Suite](./td-regression-evaluator/SKILL.md)**: Comprehensive regression model evaluation using TD_RegressionEvaluator
- **[Teradata Classification Evaluation Suite](./td-classification-evaluator/SKILL.md)**: Classification model evaluation and metrics calculation

### Text Analytics

- **[Teradata TF-IDF Text Analytics](./td-tfidf/SKILL.md)**: Term Frequency-Inverse Document Frequency for text analysis
- **[Teradata N-Gram Splitter](./td-ngram-splitter/SKILL.md)**: N-gram generation for text preprocessing
- **[Teradata Vector Distance Analytics](./td-vector-distance/SKILL.md)**: Vector distance calculations for similarity analysis

### Time Series

- **[Teradata ARIMA Time Series](./td-arima/SKILL.md)**: ARIMA modeling for time series forecasting
- **[Teradata Time Series Differencing](./td-diff/SKILL.md)**: Time series differencing for stationarity
- **[Teradata Discrete Fourier Transform](./td-dfft/SKILL.md)**: Fourier transformation for frequency domain analysis

### Advanced Analytics

- **[Teradata Sessionization Analytics](./td-sessionize/SKILL.md)**: Session analysis and user journey tracking
- **[Teradata nPath Analytics](./td-npath/SKILL.md)**: Path analysis for sequential event patterns
- **[Teradata Attribution Analytics](./td-attribution/SKILL.md)**: Marketing attribution modeling and analysis


## Total Functions Covered: 27

## Categories Include:
- **Regression**: Linear models, GLM, logistic regression
- **Classification**: Decision trees, forests, SVM, Naive Bayes
- **Clustering**: K-means, hierarchical clustering
- **Preprocessing**: Scaling, encoding, imputation, outlier detection
- **Evaluation**: Model assessment and validation metrics
- **Text Analytics**: TF-IDF, n-grams, vector analysis
- **Time Series**: ARIMA, differencing, Fourier transforms
- **Advanced Analytics**: Sessionization, path analysis, attribution

## Usage

Each skill folder contains:
- `SKILL.md` - Complete skill documentation and instructions
- `scripts/` - SQL scripts for implementation including table analysis
- `resources/` - Configuration files and templates

## Requirements

- Teradata Vantage with ClearScape Analytics enabled
- Appropriate database permissions
- Access to specified analytical functions

---

*These skills provide production-ready analytics workflows using the complete Teradata ClearScape Analytics suite with industry best practices.*

# Comprehensive Teradata UAF (Unbounded Array Framework) Skills

This collection provides specialized analytical skills for Teradata's Unbounded Array Framework (UAF) functions, covering time series analysis, digital signal processing, and model preparation.

## Unbounded Array Framework Overview

The UAF is Teradata's advanced analytics framework for:
- **End-to-end time series forecasting pipelines**
- **Digital signal processing** for complex signal analysis
- **4D spatial analytics** and high-dimensional data processing
- **Scalable analysis** of millions of products or billions of IoT sensors

## Function Categories

### Uaf Time Series

- **[Teradata ARIMA Parameter Estimation](./td-arimaestimate/SKILL.md)**: ARIMA parameter estimation for seasonal and non-seasonal AR, MA, ARMA, and ARIMA models
- **[Teradata ARIMA Forecasting](./td-arima-forecast/SKILL.md)**: ARIMA-based time series forecasting for trend and seasonal predictions
- **[Teradata Auto-Correlation Function](./td-acf/SKILL.md)**: Auto-correlation analysis for time series dependency and pattern detection
- **[Teradata Partial Auto-Correlation Function](./td-pacf/SKILL.md)**: Partial auto-correlation analysis for direct lag relationships
- **[Teradata Power Spectral Density](./td-powerspec/SKILL.md)**: Power spectrum analysis for frequency domain insights and periodicity detection
- **[Teradata Time Series Differencing](./td-diff/SKILL.md)**: Time series differencing for stationarity and trend removal
- **[Teradata Seasonal Decomposition](./td-seasonal-decompose/SKILL.md)**: Seasonal pattern decomposition and analysis
- **[Teradata Time Series Plotting](./td-plot/SKILL.md)**: Time series visualization and diagnostic plotting utilities
- **[Teradata Moving Average Forecasting](./td-movavg-forecast/SKILL.md)**: Moving average based forecasting for smoothed predictions

### Uaf Digital Signal Processing

- **[Teradata Fast Fourier Transform](./td-fft/SKILL.md)**: Fast Fourier Transform for frequency domain analysis and spectral decomposition
- **[Teradata Inverse Fast Fourier Transform](./td-ifft/SKILL.md)**: Inverse Fast Fourier Transform for time domain reconstruction
- **[Teradata Digital Signal Filtering](./td-filter/SKILL.md)**: Digital filtering for noise reduction and signal enhancement
- **[Teradata Windowing Functions](./td-window/SKILL.md)**: Signal windowing for spectral analysis and leakage reduction
- **[Teradata Signal Convolution](./td-convolution/SKILL.md)**: Convolution operations for signal processing and filtering
- **[Teradata Signal Correlation](./td-correlation/SKILL.md)**: Signal correlation analysis for similarity and delay detection
- **[Teradata Spectral Density Analysis](./td-spectral-density/SKILL.md)**: Power spectral density estimation for frequency content analysis
- **[Teradata Signal Detrending](./td-detrend/SKILL.md)**: Signal detrending for baseline correction and trend removal
- **[Teradata Signal Resampling](./td-resample/SKILL.md)**: Signal resampling and interpolation for rate conversion
- **[Teradata Signal Smoothing](./td-smoothing/SKILL.md)**: Signal smoothing and noise reduction techniques

### Uaf Model Preparation

- **[Teradata UAF Data Preparation](./td-data-preparation/SKILL.md)**: UAF-specific data preparation and validation for time series analysis
- **[Teradata Parameter Estimation Suite](./td-parameter-estimation/SKILL.md)**: Advanced parameter estimation and optimization for UAF models
- **[Teradata Automated Model Selection](./td-model-selection/SKILL.md)**: Automated model selection and comparison for optimal forecasting
- **[Teradata Time Series Cross-Validation](./td-cross-validation/SKILL.md)**: Time series specific cross-validation techniques for model validation
- **[Teradata Stationarity Testing](./td-stationarity-test/SKILL.md)**: Statistical tests for time series stationarity (ADF, KPSS, PP tests)
- **[Teradata Change Point Detection](./td-change-point/SKILL.md)**: Change point detection in time series for structural breaks
- **[Teradata Ljung-Box Test](./td-portman/SKILL.md)**: Ljung-Box portmanteau tests for model diagnostics and residual analysis


## Total UAF Functions Covered: 26

## Key Capabilities

### Time Series Analysis
- **ARIMA modeling** with automatic parameter estimation
- **Seasonal decomposition** and pattern analysis
- **Autocorrelation** and partial autocorrelation analysis
- **Power spectral density** and frequency analysis
- **Forecasting** with multiple methodologies

### Digital Signal Processing
- **Fast Fourier Transform** (FFT) and inverse FFT
- **Digital filtering** and signal enhancement
- **Windowing functions** for spectral analysis
- **Signal correlation** and convolution
- **Noise reduction** and signal smoothing

### Model Preparation
- **Automated model selection** and comparison
- **Cross-validation** for time series data
- **Stationarity testing** and validation
- **Change point detection** and analysis
- **Parameter estimation** and optimization

## Industry Applications

- **Economic forecasting** and financial modeling
- **Sales forecasting** and demand planning
- **Medical diagnostic** image analysis
- **Radar and sonar** signal processing
- **Audio and video** processing
- **IoT sensor data** analysis at scale
- **Process monitoring** and quality control

## Usage Requirements

- **Teradata Vantage** with UAF licensing
- **Time series data** with proper temporal structure
- **Database permissions** for UAF function execution
- **Adequate memory** for array processing operations

## Skill Features

Each UAF skill includes:
- **SKILL.md**: Comprehensive documentation with UAF-specific guidance
- **UAF workflow templates**: Production-ready SQL with proper array handling
- **Table analysis scripts**: Time series structure validation
- **Performance optimization**: Memory and processing considerations
- **Integration guides**: Multi-function UAF pipeline workflows

## Getting Started

1. **Choose appropriate UAF skill** based on your analytical needs
2. **Prepare time series data** with consistent temporal structure
3. **Run table analysis** to validate UAF compatibility
4. **Configure parameters** based on your data characteristics
5. **Execute UAF workflow** with proper array processing

## Performance Considerations

- **Regular sampling intervals** recommended for optimal performance
- **Memory allocation** important for large array processing
- **Temporal indexing** crucial for time series efficiency
- **Data partitioning** may be needed for very large datasets

---

*These skills provide production-ready UAF analytics using Teradata's Unbounded Array Framework with comprehensive support for time series, signal processing, and advanced modeling workflows.*
