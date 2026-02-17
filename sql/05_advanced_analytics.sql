-- ========================================
-- READMISSION INTERVALS (Date Difference)
-- ========================================

-- ========================================
-- ❌ ORIGINAL QUERY (BROKEN)
-- ========================================
SELECT 
    patient_id,
    admission_date,
    LAG(discharge_disposition) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_date,
    -- LOGIC: Subtract dates to get an integer (days)
    admission_date - LAG(discharge_disposition) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
FROM hospital_readmission;

-- ⚠️ ERRORS:
-- 1. LAG(discharge_disposition) retrieves VARCHAR ('Home', 'SNF', 'AMA') 
--    └─> NOT a DATE column!
-- 2. Trying to subtract VARCHAR from DATE
--    └─> PostgreSQL ERROR: "operator does not exist: date - character varying"
-- 3. Column alias misleading: prev_discharge_date but getting discharge_disposition


-- ========================================
-- ✅ CORRECTED QUERY (BASIC FIX)
-- ========================================
SELECT 
    patient_id,
    admission_date,
    LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_date,
    -- LOGIC: Subtract dates to get an integer (days)
    admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
FROM hospital_readmission
ORDER BY patient_id, admission_date;

-- ✅ FIXES:
-- 1. Changed LAG(discharge_disposition) → LAG(discharge_date)
-- 2. Now subtracting DATE - DATE = INTEGER (days)
-- 3. Column alias now matches the data


-- ========================================
-- SAMPLE OUTPUT (Basic Fix)
-- ========================================
/*
┌────────────┬─────────────────┬─────────────────────┬──────────┐
│ patient_id │ admission_date  │ prev_discharge_date │ days_gap │
├────────────┼─────────────────┼─────────────────────┼──────────┤
│ PAT00001   │ 2024-01-15      │ NULL                │ NULL     │ ← First admission (no previous)
│ PAT00001   │ 2024-03-20      │ 2024-01-24          │ 55       │ ← 55 days between discharge & readmission
│ PAT00001   │ 2024-05-10      │ 2024-03-29          │ 42       │ ← 42 days gap
│ PAT00002   │ 2024-01-05      │ NULL                │ NULL     │ ← First admission (no previous)
│ PAT00002   │ 2024-02-18      │ 2024-01-12          │ 37       │ ← 37 days gap
│ PAT00003   │ 2024-06-01      │ NULL                │ NULL     │ ← First admission (no previous)
└────────────┴─────────────────┴─────────────────────┴──────────┘
*/


-- ========================================
-- ENHANCED VERSION (With Context)
-- ========================================
SELECT 
    patient_id,
    admission_date,
    LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_date,
    admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap,
    
    -- Add discharge disposition to see WHERE they went
    LAG(discharge_disposition) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_disposition,
    discharge_disposition as current_discharge_disposition,
    
    -- Add clinical context
    primary_diagnosis,
    LAG(primary_diagnosis) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_diagnosis
    
FROM hospital_readmission
ORDER BY patient_id, admission_date;

-- Output Example:
/*
┌────────────┬─────────────────┬─────────────────────┬──────────┬──────────────────────┬──────────────────────┬──────────────────┬─────────────────────┐
│ patient_id │ admission_date  │ prev_discharge_date │ days_gap │ prev_disposition     │ current_disposition  │ primary_diagnosis│ prev_diagnosis      │
├────────────┼─────────────────┼─────────────────────┼──────────┼──────────────────────┼──────────────────────┼──────────────────┼─────────────────────┤
│ PAT00001   │ 2024-03-20      │ 2024-01-24          │ 55       │ Home Health          │ Home                 │ Heart Failure    │ Diabetes            │
│ PAT00002   │ 2024-02-18      │ 2024-01-12          │ 37       │ SNF                  │ Home Health          │ Pneumonia        │ COPD                │
│ PAT00003   │ 2024-04-05      │ 2024-02-28          │ 36       │ AMA                  │ Home                 │ Sepsis           │ Hypertension        │
└────────────┴─────────────────┴─────────────────────┴──────────┴──────────────────────┴──────────────────────┴──────────────────┴─────────────────────┘
*/


-- ========================================
-- VERSION WITH RISK STRATIFICATION
-- ========================================
SELECT 
    patient_id,
    admission_date,
    LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_date,
    admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap,
    readmitted_30_days,
    
    -- Flag high-risk readmissions (< 30 days)
    CASE 
        WHEN admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) <= 7 
             THEN '🚨 CRITICAL (≤7 days)'
        WHEN admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) <= 14 
             THEN '🔴 HIGH RISK (8-14 days)'
        WHEN admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) <= 30 
             THEN '🟡 MODERATE RISK (15-30 days)'
        WHEN admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) IS NULL 
             THEN '🆕 First Visit'
        ELSE '🟢 LOW RISK (30+ days)'
    END as readmission_risk_level
    
FROM hospital_readmission
WHERE admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) IS NOT NULL
      OR LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) IS NULL
ORDER BY patient_id, admission_date;

-- Output Example:
/*
┌────────────┬─────────────────┬─────────────────────┬──────────┬──────────────────┬─────────────────────────────────┐
│ patient_id │ admission_date  │ prev_discharge_date │ days_gap │ readmitted_30day │ readmission_risk_level          │
├────────────┼─────────────────┼─────────────────────┼──────────┼──────────────────┼─────────────────────────────────┤
│ PAT00001   │ 2024-03-20      │ 2024-01-24          │ 55       │ 0                │ 🟢 LOW RISK (30+ days)          │
│ PAT00002   │ 2024-02-18      │ 2024-01-12          │ 37       │ 0                │ 🟢 LOW RISK (30+ days)          │
│ PAT00003   │ 2024-04-05      │ 2024-02-28          │ 36       │ 0                │ 🟢 LOW RISK (30+ days)          │
│ PAT00004   │ 2024-05-12      │ 2024-05-05          │ 7        │ 1                │ 🚨 CRITICAL (≤7 days)          │
│ PAT00005   │ 2024-06-18      │ 2024-06-08          │ 10       │ 1                │ 🔴 HIGH RISK (8-14 days)       │
└────────────┴─────────────────┴─────────────────────┴──────────┴──────────────────┴─────────────────────────────────┘
*/


-- ========================================
-- AGGREGATE ANALYSIS: Days Gap Distribution
-- ========================================
SELECT 
    CASE 
        WHEN days_gap <= 7 THEN '≤7 days (Critical)'
        WHEN days_gap <= 14 THEN '8-14 days (High Risk)'
        WHEN days_gap <= 30 THEN '15-30 days (Moderate)'
        WHEN days_gap > 30 THEN '>30 days (Low Risk)'
    END as readmission_window,
    COUNT(*) as patient_count,
    ROUND(AVG(days_gap), 1) as avg_days_gap,
    MIN(days_gap) as min_days,
    MAX(days_gap) as max_days,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_of_readmissions
FROM (
    SELECT 
        patient_id,
        admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
    FROM hospital_readmission
) gaps
WHERE days_gap IS NOT NULL  -- Only look at readmissions (not first visits)
GROUP BY readmission_window
ORDER BY 
    CASE 
        WHEN readmission_window = '≤7 days (Critical)' THEN 1
        WHEN readmission_window = '8-14 days (High Risk)' THEN 2
        WHEN readmission_window = '15-30 days (Moderate)' THEN 3
        WHEN readmission_window = '>30 days (Low Risk)' THEN 4
    END;

-- Output Example:
/*
┌──────────────────────────┬────────────────┬────────────────┬──────────┬──────────┬────────────────────┐
│ readmission_window       │ patient_count  │ avg_days_gap   │ min_days │ max_days │ pct_of_readmissions│
├──────────────────────────┼────────────────┼────────────────┼──────────┼──────────┼────────────────────┤
│ ≤7 days (Critical)       │ 145            │ 4.5            │ 1        │ 7        │ 14.82%             │
│ 8-14 days (High Risk)    │ 167            │ 11.2           │ 8        │ 14       │ 17.15%             │
│ 15-30 days (Moderate)    │ 298            │ 22.4           │ 15       │ 30       │ 30.64%             │
│ >30 days (Low Risk)      │ 365            │ 95.3           │ 31       │ 365      │ 37.49%             │
└──────────────────────────┴────────────────┴────────────────┴──────────┴──────────┴────────────────────┘

KEY INSIGHT: 
  • 31.97% of readmissions occur within 30 days (high risk!)
  • 14.82% occur within 7 days (critical intervention needed)
*/


-- ========================================
-- CTE VERSION (Cleaner & More Readable)
-- ========================================
WITH patient_readmissions AS (
    SELECT 
        patient_id,
        admission_date,
        discharge_date,
        LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_date,
        admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap,
        ROW_NUMBER() OVER(PARTITION BY patient_id ORDER BY admission_date) as visit_number,
        primary_diagnosis,
        LAG(primary_diagnosis) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_diagnosis,
        readmitted_30_days
    FROM hospital_readmission
)
SELECT 
    patient_id,
    visit_number,
    admission_date,
    prev_discharge_date,
    days_gap,
    primary_diagnosis,
    prev_diagnosis,
    readmitted_30_days,
    CASE 
        WHEN days_gap IS NULL THEN '🆕 First Visit'
        WHEN days_gap <= 7 THEN '🚨 CRITICAL (≤7 days)'
        WHEN days_gap <= 14 THEN '🔴 HIGH RISK (8-14 days)'
        WHEN days_gap <= 30 THEN '🟡 MODERATE RISK (15-30 days)'
        ELSE '🟢 LOW RISK (30+ days)'
    END as risk_category
FROM patient_readmissions
WHERE visit_number > 1  -- Only show readmissions (exclude first visits)
ORDER BY patient_id, admission_date;


-- ========================================
-- CLINICAL INSIGHTS: When do specific diagnoses get readmitted?
-- ========================================
SELECT 
    primary_diagnosis,
    COUNT(*) as readmission_count,
    ROUND(AVG(days_gap), 1) as avg_days_to_readmit,
    MIN(days_gap) as min_days,
    MAX(days_gap) as max_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_gap), 1) as median_days
FROM (
    SELECT 
        patient_id,
        primary_diagnosis,
        admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
    FROM hospital_readmission
) gaps
WHERE days_gap IS NOT NULL  -- Only readmissions
GROUP BY primary_diagnosis
ORDER BY avg_days_to_readmit ASC;  -- Diagnoses with fastest readmission first

-- Output Example:
/*
┌──────────────────┬───────────────────┬──────────────────────┬──────────┬──────────┬──────────────┐
│ primary_diagnosis│ readmission_count │ avg_days_to_readmit  │ min_days │ max_days │ median_days  │
├──────────────────┼───────────────────┼──────────────────────┼──────────┼──────────┼──────────────┤
│ Heart Failure    │ 156               │ 18.4                 │ 2        │ 180      │ 14.0         │
│ Sepsis           │ 124               │ 21.7                 │ 1        │ 195      │ 17.0         │
│ MI               │ 98                │ 25.3                 │ 3        │ 200      │ 22.0         │
│ Pneumonia        │ 67                │ 35.2                 │ 5        │ 210      │ 32.0         │
│ COPD             │ 54                │ 42.1                 │ 8        │ 225      │ 38.0         │
└──────────────────┴───────────────────┴──────────────────────┴──────────┴──────────┴──────────────┘

KEY INSIGHT: 
  • Heart Failure has fastest readmission (avg 18.4 days)
  • Requires intensive monitoring & intervention
*/


-- ========================================
-- DATA TYPE EXPLANATION
-- ========================================

/*
📊 Column Data Types:

admission_date: DATE
  └─> Format: 2024-01-15
  └─> PostgreSQL date type

discharge_date: DATE
  └─> Format: 2024-01-24
  └─> PostgreSQL date type

discharge_disposition: VARCHAR(50)
  └─> Format: 'Home', 'Home Health', 'SNF', 'AMA'
  └─> TEXT type (NOT a date!)

days_gap: DATE - DATE = INTEGER
  └─> Result: 55 (days as integer)
  └─> PostgreSQL date arithmetic returns days
*/


-- ========================================
-- LAG() WINDOW FUNCTION EXPLANATION
-- ========================================

/*
LAG() gets the PREVIOUS row's value within a partition

Syntax: LAG(column) OVER(PARTITION BY group ORDER BY order_by_column)

Example:
┌────────────┬─────────────────┬──────────────────────────────┬───────────────────┐
│ patient_id │ admission_date  │ discharge_date (current row) │ LAG(discharge_date)│
├────────────┼─────────────────┼──────────────────────────────┼───────────────────┤
│ PAT00001   │ 2024-01-15      │ 2024-01-24                   │ NULL (first row)   │
│ PAT00001   │ 2024-03-20      │ 2024-03-29                   │ 2024-01-24 ← prev  │
│ PAT00001   │ 2024-05-10      │ 2024-05-19                   │ 2024-03-29 ← prev  │
└────────────┴─────────────────┴──────────────────────────────┴───────────────────┘

PARTITION BY patient_id
  └─> Each patient's data calculated separately
  └─> PAT00001 and PAT00002 don't mix

ORDER BY admission_date
  └─> Chronological order (oldest to newest)
*/


-- ========================================
-- COMMON MISTAKES & HOW TO AVOID
-- ========================================

/*
❌ MISTAKE 1: Using wrong column
   LAG(discharge_disposition) → Returns VARCHAR, not DATE
   ✅ FIX: LAG(discharge_date) → Returns DATE

❌ MISTAKE 2: Forgetting NULL check
   WHERE days_gap > 0 -- Fails on NULL values!
   ✅ FIX: WHERE days_gap IS NOT NULL

❌ MISTAKE 3: Not partitioning correctly
   LAG(discharge_date) OVER(ORDER BY admission_date)
   └─> This mixes patients! PAT1's gap includes PAT2's discharge
   ✅ FIX: PARTITION BY patient_id

❌ MISTAKE 4: Not filtering for first visit
   SELECT ... WHERE visit_number = 1
   └─> First visits have NULL days_gap (no previous discharge)
   ✅ FIX: WHERE visit_number > 1 (to see only readmissions)
*/


-- ========================================
-- PERFORMANCE TIPS
-- ========================================

/*
🚀 OPTIMIZATION:

1. Add INDEX on (patient_id, admission_date)
   CREATE INDEX idx_patient_admits 
   ON hospital_readmission(patient_id, admission_date)
   └─> Speeds up PARTITION BY and ORDER BY

2. Materialize results to temp table if querying multiple times
   CREATE TEMP TABLE readmission_gaps AS (SELECT ... from above)
   SELECT * FROM readmission_gaps WHERE days_gap <= 30

3. Use CTE for readability (shown above)
   └─> Easier to debug individual steps
*/
