# Data Profiling Configuration

## Profiling Parameters

### General Settings
- **Database Name**: Target database containing the table to profile
- **Table Name**: Table to be profiled
- **Profiling Scope**: Full (all columns) or Selective (specified columns only)

### Numeric Column Profiling
- **Statistics Level**: Basic, Standard, or Comprehensive
  - **Basic**: Count, Min, Max, Mean, Median
  - **Standard**: Basic + Std Dev, Quartiles, Percentiles
  - **Comprehensive**: Standard + Skewness, Kurtosis, CV

- **Percentiles**: 1st, 5th, 10th, 25th, 50th, 75th, 90th, 95th, 99th
- **Distribution Analysis**: Enable/Disable histogram generation
- **Histogram Bins**: 10, 20, or 50 (default: 20)

### Categorical Column Profiling
- **Frequency Analysis**: Top K most frequent values (default: 10)
- **Cardinality Threshold**: Maximum distinct values for detailed analysis (default: 100)
- **Rare Value Threshold**: Percentage below which values are considered rare (default: 1%)
- **Entropy Calculation**: Enable/Disable

### Outlier Detection
- **Methods**: IQR, Z-Score, Modified Z-Score, Percentile
- **IQR Multiplier**: 1.5 (standard) or 3.0 (extreme outliers only)
- **Z-Score Threshold**: 2 or 3 standard deviations
- **Percentile Thresholds**: 1st/99th or 5th/95th

### Correlation Analysis
- **Correlation Method**: Pearson (default), Spearman
- **Significance Threshold**: |r| > 0.7 for reporting
- **Matrix Generation**: Full or Upper Triangle only

### Data Quality Scoring
- **Completeness Weight**: 30% (default)
- **Uniqueness Weight**: 25% (default)
- **Validity Weight**: 25% (default)
- **Consistency Weight**: 20% (default)

### Quality Thresholds
- **Excellent**: Score >= 90
- **Good**: Score >= 70
- **Fair**: Score >= 50
- **Poor**: Score < 50

## Performance Settings

### Sampling
- **Enable Sampling**: For tables > 10M rows
- **Sample Size**: 1M rows or 10% of table (whichever is smaller)
- **Sampling Method**: Random or Systematic

### Parallelism
- **Parallel Execution**: Enable for large tables
- **Max Concurrent Queries**: 4 (adjust based on system resources)

## Output Options

### Report Formats
- **Detailed Reports**: Full statistical analysis per column
- **Summary Reports**: Executive summary only
- **Quality Dashboard**: Quality scores and issues only

### Table Retention
- **Keep Profiling Tables**: Specify duration (7, 30, 90 days, or Permanent)
- **Archive Old Profiles**: Enable/Disable
- **Archive Location**: Database and naming convention

## Advanced Options

### Business Rules
- **Valid Ranges**: Define expected min/max for numeric columns
- **Valid Formats**: Define patterns for text columns
- **Valid Values**: Define allowed categories for categorical columns

### Custom Metrics
- **Business-Specific KPIs**: Define custom quality metrics
- **Domain-Specific Validations**: Custom validation rules

## Integration Settings

### Downstream Systems
- **Export Format**: CSV, JSON, or Table
- **Notification**: Email alerts for quality issues
- **Scheduling**: Frequency for automated profiling

---

*Configuration settings can be adjusted based on table characteristics, business requirements, and system resources.*
