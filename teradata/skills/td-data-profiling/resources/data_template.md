# Data Profiling Template

## Table Information

**Database**: `{database_name}`
**Table**: `{table_name}`
**Description**: {Brief description of table purpose and contents}
**Owner**: {Data owner or team}
**Update Frequency**: {How often is data refreshed}

## Profiling Scope

### Columns to Profile

#### Numeric Columns
- `{numeric_column_1}` - {Description}
- `{numeric_column_2}` - {Description}
- `{numeric_column_3}` - {Description}

#### Categorical Columns
- `{categorical_column_1}` - {Description}
- `{categorical_column_2}` - {Description}

#### Date/Time Columns
- `{datetime_column_1}` - {Description}

#### Text Columns
- `{text_column_1}` - {Description}

## Expected Data Characteristics

### Numeric Column Expectations

**{numeric_column_1}**
- Expected Range: {min} to {max}
- Expected Mean: Approximately {value}
- Missing Values: Expected < {percentage}%
- Distribution: {Normal, Skewed, Uniform, etc.}

**{numeric_column_2}**
- Expected Range: {min} to {max}
- Expected Mean: Approximately {value}
- Missing Values: Expected < {percentage}%
- Distribution: {Normal, Skewed, Uniform, etc.}

### Categorical Column Expectations

**{categorical_column_1}**
- Expected Values: {List of valid categories}
- Expected Cardinality: {number} distinct values
- Missing Values: Expected < {percentage}%
- Most Common: {expected mode}

**{categorical_column_2}**
- Expected Values: {List of valid categories}
- Expected Cardinality: {number} distinct values
- Missing Values: Expected < {percentage}%

## Business Rules and Constraints

### Value Constraints
- `{column_name}` must be >= 0 (no negative values)
- `{column_name}` must be in ('Value1', 'Value2', 'Value3')
- `{date_column}` must be between {start_date} and {end_date}

### Referential Integrity
- `{foreign_key_column}` references `{parent_table}.{parent_key}`
- Expected orphan records: < 1%

### Uniqueness Constraints
- `{id_column}` should be unique (primary key)
- `{compound_key_1}`, `{compound_key_2}` combination should be unique

## Data Quality Targets

### Completeness Targets
- Critical columns: 100% complete
- Important columns: >= 95% complete
- Optional columns: >= 80% complete

### Accuracy Targets
- Value validity: >= 98% within expected ranges
- Format consistency: >= 95% conforming to patterns

### Timeliness Targets
- Data freshness: Updated within {timeframe}
- Maximum age: Records no older than {timeframe}

## Profiling Checklist

- [ ] Table discovery and metadata extraction completed
- [ ] Numeric column profiling executed
- [ ] Categorical column profiling executed
- [ ] Distribution analysis performed
- [ ] Outlier detection completed
- [ ] Correlation analysis executed (if applicable)
- [ ] Data quality metrics calculated
- [ ] Quality scorecard generated
- [ ] Comprehensive report compiled
- [ ] Issues identified and prioritized
- [ ] Recommendations documented

## Known Issues and Considerations

### Data Source Limitations
- {Known data source issues or limitations}
- {Expected data anomalies}

### Historical Context
- {Previous profiling findings}
- {Trends observed over time}

### Special Handling
- {Columns requiring special treatment}
- {Business logic affecting data values}

## Stakeholder Requirements

### Primary Stakeholders
- **Name/Team**: {Stakeholder}
  - Key concerns: {Specific data quality concerns}
  - Priority metrics: {Which metrics matter most}

### Reporting Requirements
- Frequency: {Daily, Weekly, Monthly}
- Format: {Dashboard, Report, Email}
- Audience: {Technical, Business, Executive}

## Follow-up Actions

### After Profiling
1. Review findings with data owner
2. Prioritize data quality issues
3. Develop data cleansing plan
4. Implement monitoring for critical metrics
5. Schedule next profiling cycle

### Data Quality Improvement Plan
- **Short-term (< 1 month)**: {Actions}
- **Medium-term (1-3 months)**: {Actions}
- **Long-term (> 3 months)**: {Actions}

---

## Example Profiling Request

```sql
-- Example: Profile customer transactions table
Database: retail_analytics
Table: customer_transactions

Numeric Columns to Profile:
- transaction_amount (Expected range: $0.01 to $10,000)
- customer_age (Expected range: 18 to 100)
- items_purchased (Expected range: 1 to 50)

Categorical Columns to Profile:
- customer_segment (Expected: 'Gold', 'Silver', 'Bronze', 'New')
- product_category (Expected: 10-15 distinct categories)
- payment_method (Expected: 'Credit', 'Debit', 'Cash', 'Digital')

Quality Targets:
- Overall completeness: >= 95%
- No duplicate transaction_id values
- All amounts >= 0
- Dates within last 2 years
```

---

*Use this template to define profiling scope and expectations before executing the data profiling workflow.*
