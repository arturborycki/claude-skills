# Teradata Workload Management Skills

**Reusable workflows for autonomous TDWM operations and system monitoring**

This directory contains specialized skills that compose multiple TDWM MCP tools and resources to accomplish complex operational tasks. Skills are designed for LLM agent consumption and provide structured workflows for common TDWM scenarios.

## How LLMs Should Use Skills

Skills are invoked by name and execute multi-step workflows autonomously:

```
When user requests: "Queries are slow, check throttles"
→ LLM should invoke: optimize-throttles skill
→ Skill will: analyze, recommend, and optionally execute throttle adjustments
```

Each skill provides:
- **Clear trigger conditions** (when to use this skill)
- **Step-by-step workflow** (what the skill does)
- **Autonomous capabilities** (what actions it can execute)
- **Related skills** (what to use next)

---

## Quick Decision Tree

Use this tree to select the appropriate skill based on user intent:

```
USER GOAL?
│
├─ MONITOR/CHECK SYSTEM
│  │
│  ├─ "Show sessions" / "What's running" / "Check active users"
│  │  → monitor-sessions
│  │
│  ├─ "Query performance" / "Slow queries" / "Query history"
│  │  → monitor-queries
│  │
│  ├─ "System health" / "CPU/memory" / "Capacity" / "AMP load"
│  │  → monitor-resources
│  │
│  └─ "Workload distribution" / "Classification" / "TASM effectiveness"
│     → monitor-workloads
│
├─ OPTIMIZE/FIX CONFIGURATION
│  │
│  ├─ "Throttle" keywords / "Limit queries" / "Concurrency"
│  │  → optimize-throttles (autonomous: create/modify/enable throttles)
│  │
│  ├─ "Classification" / "Query bands" / "Misclassified" / "DEFAULT workload"
│  │  → tune-workloads (autonomous: add criteria to filters/throttles)
│  │
│  └─ "New workload" / "Create filter" / "Route queries" / "Workload lifecycle"
│     → manage-workloads (autonomous: create filters, throttles, enable/disable)
│
└─ CONTROL/TAKE ACTION
   │
   ├─ "Abort session" / "Kill query" / "Terminate user"
   │  → control-sessions (control: terminate sessions)
   │
   ├─ "Analyze query" / "Query plan" / "Optimize query"
   │  → analyze-performance (analysis: deep query investigation)
   │
   └─ "Delay queue" / "Release delayed" / "Stuck queries"
      → manage-queues (control: manage delay queue)
```

---

## Quick Reference Table

| Skill | Category | Primary Use | Execution Type | Common Triggers |
|-------|----------|-------------|----------------|-----------------|
| **monitor-sessions** | Monitoring | Track active sessions, SQL text, blocking | Read-only | "show sessions", "what's running", "blocking", "active users" |
| **monitor-queries** | Monitoring | Query history, bands, performance trends | Read-only | "slow queries", "query log", "query bands", "query volume" |
| **monitor-resources** | Monitoring | CPU, memory, I/O, AMP load, capacity | Read-only | "system health", "capacity", "CPU usage", "AMP skew" |
| **monitor-workloads** | Monitoring | Workload distribution, TASM statistics | Read-only | "workload status", "classification", "TASM", "distribution" |
| **optimize-throttles** | Optimization | Adjust throttle limits for workloads | **Autonomous** | "throttle", "limit queries", "concurrency", "protect resources" |
| **tune-workloads** | Optimization | Fix classification, add criteria | **Autonomous** | "classification", "misclassified", "query bands", "DEFAULT workload" |
| **manage-workloads** | Optimization | Create/enable filters and throttles | **Autonomous** | "new workload", "create filter", "route queries", "enable/disable" |
| **analyze-performance** | Analysis | Deep query optimization analysis | Read-only | "analyze query", "query plan", "optimize", "explain" |
| **control-sessions** | Control | Abort sessions and queries | **Control Action** | "abort", "kill", "terminate", "stop query" |
| **manage-queues** | Control | Manage delay queue operations | **Control Action** | "delay queue", "release", "stuck queries", "queued" |

**Execution Types:**
- **Read-only**: Monitoring and analysis, no system changes
- **Autonomous**: Can create/modify/enable configuration autonomously
- **Control Action**: Can terminate sessions or release queues (requires caution)

---

## Skills by Category

### Optimization Skills (Autonomous)

These skills can analyze current configuration and autonomously execute changes:

#### optimize-throttles
**Analyze throttle behavior and autonomously create/modify throttles to balance resource allocation**

**When to Use:**
- User mentions "throttle", "limit", "concurrency", or "too many queries"
- Queries are delayed or system is overloaded
- Need to protect specific workload from monopolizing resources
- After adding new workloads or applications
- System overload requiring immediate throttle creation

**What It Does:**
1. Analyzes current throttle behavior and resource usage
2. Calculates optimal throttle limits based on capacity and SLAs
3. **Autonomously creates or modifies throttles** using Priority 1 tools
4. Enables throttles and activates ruleset changes
5. Verifies changes and monitors impact

**Related Skills:**
- Use **monitor-resources** first to understand capacity constraints
- Use **monitor-workloads** to see workload distribution
- Use **tune-workloads** if classification needs adjustment
- Use **emergency-response** for crisis situations

---

#### tune-workloads
**Analyze classification and autonomously add criteria to fix query routing**

**When to Use:**
- User mentions "classification", "query bands", "misclassified", or "DEFAULT workload"
- Queries landing in wrong workload
- Need to add classification rules to existing filter
- Application not properly classified
- TASM statistics show low classification rate

**What It Does:**
1. Analyzes query classification patterns and TASM events
2. Identifies classification gaps and mismatches
3. **Autonomously adds classification criteria** to filters/throttles
4. Adds sub-criteria for fine-grained control (FTSCAN, MINSTEPTIME, etc.)
5. Activates changes and verifies classification improvements

**Related Skills:**
- Use **monitor-workloads** first to see classification effectiveness
- Use **monitor-queries** to identify misclassified queries
- Use **manage-workloads** if need to create entirely new filter
- Use **optimize-throttles** to adjust limits after fixing classification

---

#### manage-workloads
**Autonomously create filters, throttles, and manage workload lifecycle**

**When to Use:**
- User mentions "new workload", "create filter", "route queries", or "enable/disable"
- Implementing new workload for application or user group
- Creating filters to route queries to workload
- Adding throttles to protect workload resources
- Seasonal or emergency workload activation/deactivation

**What It Does:**
1. Reviews current workload configuration and gaps
2. **Autonomously creates filters** to route queries to workloads
3. **Autonomously creates throttles** to protect workload resources
4. Enables/disables filters and throttles for lifecycle management
5. Verifies workload implementation and monitors impact

**Related Skills:**
- Use **monitor-workloads** first to understand current configuration
- Use **tune-workloads** to add criteria to existing filters
- Use **optimize-throttles** to adjust throttle limits later
- Use **discover-configuration** to inventory existing configurations

---

### Monitoring Skills (Read-Only)

These skills provide real-time monitoring and analysis without making changes:

#### monitor-sessions
**Monitor active sessions, view SQL text, identify blocking, and optionally abort sessions**

**When to Use:**
- User asks "what's running", "show sessions", "active users", or "blocked queries"
- Investigating performance issues or session activity
- Need to see SQL text for specific sessions
- Checking for blocking or lock contention
- Response to user complaints about slow queries

**What It Does:**
1. Provides real-time snapshot of all active sessions (using MCP resources)
2. Shows session details: user, runtime, CPU, I/O, state
3. Displays SQL text and execution steps for sessions
4. Identifies blocking chains and lock contention
5. Optionally terminates sessions (control action)

**Related Skills:**
- Use **monitor-queries** for historical query analysis
- Use **control-sessions** for detailed session management
- Use **monitor-resources** to correlate sessions with resource usage
- Use **emergency-response** for crisis situations

---

#### monitor-queries
**Track query execution, analyze query bands, and identify performance patterns**

**When to Use:**
- User asks about "query performance", "slow queries", "query history", or "query bands"
- Analyzing query performance trends over time
- Tracking queries by application or workload
- Reviewing historical query execution
- Identifying slow or resource-intensive queries

**What It Does:**
1. Provides real-time query distribution across workloads (using MCP resources)
2. Shows query bands and classification patterns
3. Analyzes historical query logs for performance trends
4. Reviews TASM classification decisions and effectiveness
5. Identifies throttle delays and workload classification issues

**Related Skills:**
- Use **monitor-sessions** for real-time active queries
- Use **analyze-performance** for detailed query optimization
- Use **tune-workloads** to fix classification issues
- Use **optimize-throttles** to adjust throttle limits

---

#### monitor-resources
**Monitor CPU, memory, I/O, AMP load, and capacity for system health**

**When to Use:**
- User asks "system health", "capacity", "CPU usage", "memory", "I/O", or "AMP load"
- Checking if system is overloaded or underutilized
- Investigating resource bottlenecks or performance degradation
- Capacity planning or growth projections
- Diagnosing AMP skew issues

**What It Does:**
1. Provides real-time resource metrics (CPU, memory, I/O) using MCP resources
2. Monitors AMP processor load and identifies skew
3. Analyzes capacity headroom and growth runway
4. Identifies top resource consumers (users, queries)
5. Correlates resources with sessions and workload activity

**Related Skills:**
- Use **monitor-sessions** to identify high-resource sessions
- Use **monitor-queries** to correlate queries with resource usage
- Use **control-sessions** to abort high-resource sessions
- Use **emergency-response** for critical resource exhaustion

---

#### monitor-workloads
**Monitor workload distribution, TASM statistics, and classification effectiveness**

**When to Use:**
- User asks "workload status", "classification", "TASM", "distribution", or "workload config"
- Understanding how queries are being classified
- Investigating workload distribution or rule effectiveness
- Reviewing TASM performance and statistics
- Assessing workload balance and priority effectiveness

**What It Does:**
1. Provides real-time workload distribution (using MCP resources)
2. Shows active/inactive workloads with status
3. Analyzes TASM classification effectiveness and statistics
4. Discovers filters and throttles per workload (using MCP resources)
5. Compares actual vs designed workload usage

**Related Skills:**
- Use **tune-workloads** to fix classification issues
- Use **manage-workloads** to create filters/throttles
- Use **optimize-throttles** to adjust throttle limits
- Use **discover-configuration** for systematic audit

---

### Control & Analysis Skills

These skills provide deep analysis or execute control actions:

#### analyze-performance
**Deep analysis of query performance, execution plans, and optimization opportunities**

**When to Use:**
- User asks "analyze query", "query plan", "optimize", "explain", or "why is this slow"
- Need detailed query optimization analysis
- Investigating specific slow query
- Understanding query execution strategy
- Identifying query tuning opportunities

**What It Does:**
1. Analyzes query execution plans and statistics
2. Identifies performance bottlenecks (full scans, joins, skew)
3. Reviews query complexity and resource consumption
4. Provides optimization recommendations (indexes, statistics, rewrites)
5. Compares execution patterns across similar queries

**Related Skills:**
- Use **monitor-queries** first to identify slow queries
- Use **monitor-resources** to understand resource constraints
- Use **monitor-sessions** to see current query execution
- Use **tune-workloads** if classification affects performance

---

#### control-sessions
**Manage and abort sessions with detailed control capabilities**

**When to Use:**
- User asks "abort", "kill", "terminate", "stop query", or "end session"
- Need to terminate runaway or problematic sessions
- Emergency response to system overload
- Managing specific user or application sessions
- Responding to blocking or lock contention

**What It Does:**
1. Lists sessions with filtering and search capabilities
2. Provides detailed session information and SQL text
3. **Terminates individual sessions or all sessions for user**
4. Manages session lifecycle (abort, monitor, verify)
5. Documents termination decisions and impact

**Related Skills:**
- Use **monitor-sessions** first to identify problematic sessions
- Use **analyze-performance** to understand why session is slow
- Use **emergency-response** for system-wide crisis
- Always document control actions taken

---

#### manage-queues
**Manage delay queue operations and release delayed queries**

**When to Use:**
- User asks "delay queue", "release", "stuck queries", "queued", or "waiting queries"
- Queries stuck in delay queue
- Need to release delayed queries manually
- Understanding throttle delay behavior
- Managing delay queue during maintenance or emergency

**What It Does:**
1. Displays queries in delay queue with wait times
2. Shows why queries are delayed (throttle limits, resource constraints)
3. **Releases delayed queries** selectively or in bulk
4. Monitors delay queue trends and patterns
5. Coordinates with throttle management

**Related Skills:**
- Use **monitor-workloads** to see delay queue statistics
- Use **optimize-throttles** to adjust throttle limits causing delays
- Use **monitor-queries** to understand query patterns
- Use **emergency-response** if delays are system-wide

---

## Skill Selection Guidelines

### How to Chain Skills

Skills are designed to work together in workflows:

**Typical Workflow Pattern:**
```
1. Monitor (understand current state)
   → Use monitor-* skills

2. Analyze (identify root cause)
   → Use analyze-* or monitor-* skills with deeper analysis

3. Optimize (fix configuration)
   → Use optimization skills (autonomous execution)

4. Verify (confirm changes worked)
   → Use monitor-* skills again
```

**Common Workflow Examples:**

**Performance Issue Workflow:**
```
User: "Queries are slow"
1. monitor-resources → Check system health
2. monitor-sessions → Identify slow sessions
3. analyze-performance → Deep dive on slow query
4. optimize-throttles → Adjust limits if needed
5. monitor-resources → Verify improvement
```

**Classification Issue Workflow:**
```
User: "Queries in wrong workload"
1. monitor-workloads → See classification effectiveness
2. monitor-queries → Identify misclassified queries
3. tune-workloads → Add classification criteria
4. monitor-workloads → Verify classification improved
```

**Capacity Planning Workflow:**
```
User: "Do we have capacity?"
1. monitor-resources → Check current utilization
2. monitor-queries → Analyze query trends
3. monitor-workloads → See workload distribution
4. Report capacity headroom and projections
```

**Emergency Response Workflow:**
```
User: "System is down!"
1. monitor-resources → Identify bottleneck
2. monitor-sessions → Find heavy users
3. control-sessions → Abort runaway queries
4. optimize-throttles → Create emergency throttle
5. monitor-resources → Verify recovery
```

### Keyword Mapping to Skills

LLMs should recognize these keywords and map to appropriate skills:

| Keywords | Skill |
|----------|-------|
| throttle, limit, concurrency, protect, too many | **optimize-throttles** |
| classification, query band, misclassified, DEFAULT, route | **tune-workloads** |
| new workload, create filter, enable, disable, lifecycle | **manage-workloads** |
| sessions, what's running, active, blocking, SQL text | **monitor-sessions** |
| queries, slow, history, performance, query log | **monitor-queries** |
| CPU, memory, I/O, capacity, health, AMP | **monitor-resources** |
| workload, distribution, TASM, classification rate | **monitor-workloads** |
| analyze, explain, query plan, optimize, why slow | **analyze-performance** |
| abort, kill, terminate, stop, end session | **control-sessions** |
| delay queue, release, stuck, waiting, queued | **manage-queues** |

### When Multiple Skills Apply

If user request matches multiple skills:

1. **Start with monitoring** - Always understand current state first
2. **Most specific wins** - Choose skill most directly addressing the request
3. **Chain skills** - Use multiple skills in sequence if needed

**Example:**
```
User: "ETL queries are slow and being throttled"

Matches:
- monitor-queries (slow queries)
- optimize-throttles (throttled)

Approach:
1. monitor-queries → Confirm ETL is slow
2. monitor-workloads → Check throttle statistics
3. optimize-throttles → Adjust throttle limits
```

---

## Skill Files

Each skill is documented in its own SKILL.md file:

**Optimization:**
- `/skills/optimization/optimize-throttles/SKILL.md`
- `/skills/optimization/tune-workloads/SKILL.md`

**Control:**
- `/skills/control/manage-workloads/SKILL.md`
- `/skills/control/control-sessions/SKILL.md`
- `/skills/control/manage-queues/SKILL.md`

**Monitoring:**
- `/skills/monitoring/monitor-sessions/SKILL.md`
- `/skills/monitoring/monitor-queries/SKILL.md`
- `/skills/monitoring/monitor-resources/SKILL.md`
- `/skills/monitoring/monitor-workloads/SKILL.md`

**Analysis:**
- `/skills/optimization/analyze-performance/SKILL.md`

---

## Version

Skills designed for **tdwm-mcp v1.5.0+**

Skills leverage:
- 46 MCP tools (33 core + 13 configuration management)
- 39 MCP resources (reference data, templates, discovery)
- Autonomous configuration capabilities (Priority 1 tools)

---

**For questions or contributions, see main project README.md**
