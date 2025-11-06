---
name: analyze-performance
description: Analyze system performance using throttle statistics, query logs, and resource metrics to identify bottlenecks and optimization opportunities
---

# Analyze Performance

Perform comprehensive performance analysis across queries, sessions, workloads, and system resources to identify bottlenecks, inefficiencies, and optimization opportunities.

## Instructions

### When to Use This Skill
- User reports performance issues or slow queries
- Need to identify system bottlenecks
- Conducting regular performance reviews
- Preparing optimization recommendations
- Investigating SLA violations

### Available MCP Tools
- `show_throttle_statistics` - View throttle stats by query/session/workload
- `show_query_log` - Access historical query performance
- `monitor_amp_load` - Check processor utilization patterns
- `show_awt_resources` - Review task resource allocation
- `show_tasm_statistics` - Analyze workload management effectiveness
- `show_top_consumers` - Identify resource-heavy users/queries

### Step-by-Step Workflow

1. **Gather Performance Baseline**
   - Collect current system metrics (CPU, memory, I/O)
   - Review recent query performance trends
   - Identify normal vs abnormal patterns

2. **Analyze Throttling Behavior**
   - Use `show_throttle_statistics` at different levels (query/session/workload)
   - Identify excessive throttling indicating resource constraints
   - Determine if throttles are working as designed or causing issues

3. **Examine Query Performance**
   - Use `show_query_log` to find slow or resource-intensive queries
   - Sort by execution time, CPU time, I/O wait
   - Identify outliers and frequently-problematic queries

4. **Check Resource Utilization**
   - Use `monitor_amp_load` to find CPU bottlenecks or skew
   - Check `show_awt_resources` for concurrency limits
   - Use `show_top_consumers` to identify resource hogs

5. **Review Workload Management**
   - Use `show_tasm_statistics` to see if TASM is managing effectively
   - Check if workload rules are achieving desired priority
   - Identify workloads with poor performance

6. **Identify Root Causes**
   - Correlate findings across different data sources
   - Distinguish between symptoms and root causes
   - Categorize issues: query optimization, configuration, capacity, workload management

7. **Develop Recommendations**
   - Prioritize issues by impact and effort
   - Suggest specific optimizations:
     - Query rewrites or index additions
     - Workload rule adjustments
     - Throttle or priority tuning
     - Capacity additions
   - Provide expected impact for each recommendation

## Examples

### Example 1: Monthly Performance Review
```
User: "Analyze overall system performance for the past month"

Action:
1. Pull query log statistics for the month
2. Check throttle statistics trends
3. Review TASM effectiveness metrics
4. Identify top 5 performance issues
5. Provide summary report with recommendations
```

### Example 2: Troubleshoot Slow Queries
```
User: "Our reports are running slow, find out why"

Action:
1. Use show_query_log filtered for reporting queries
2. Compare recent performance vs historical baseline
3. Check if being throttled via show_throttle_statistics
4. Use monitor_amp_load to check system load during report times
5. Identify cause: "Reports delayed by 45% due to concurrent ETL workload"
6. Recommend: "Adjust workload priorities or schedule separation"
```

### Example 3: Capacity vs Configuration Issue
```
User: "Do we need more hardware or just better tuning?"

Action:
1. Check peak resource utilization across all metrics
2. Analyze query efficiency (long runtime but low resource use = inefficient)
3. Review throttle statistics (high throttling = capacity issue)
4. Check workload distribution (misclassification = config issue)
5. Conclude: "70% capacity, but poor query distribution - tuning needed"
```

### Example 4: Identify Optimization Opportunities
```
User: "What should we optimize first?"

Action:
1. Get top consumers and their query patterns
2. Analyze query log for repeated slow queries
3. Check for AMP skew or data distribution issues
4. Calculate potential impact of each optimization
5. Prioritize: "Optimize daily aggregation query - runs 100x/day, 15min each"
```

## Best Practices

- Always establish baseline before diagnosing performance issues
- Look for patterns over time, not just point-in-time snapshots
- Correlate multiple data sources to confirm root causes
- Distinguish between capacity constraints and configuration issues
- Consider business context when prioritizing optimizations
- Calculate ROI: time saved vs effort to implement
- Test optimization hypotheses with data before implementing
- Monitor trends to catch degradation before it becomes critical
- Document findings and track improvement over time
- Consider interdependencies when recommending changes
