# 📚 Complete Query Reference Guide

## Table of Contents

- [Data Cleaning Queries](#data-cleaning-queries) (8 queries)
- [Basic Aggregation Queries](#basic-aggregation-queries) (12 queries)
- [Window Function Queries](#window-function-queries) (15 queries)
- [Clinical Risk Analysis](#clinical-risk-analysis) (10 queries)
- [Financial Analytics](#financial-analytics) (8 queries)
- [Temporal Analysis](#temporal-analysis) (7 queries)
- [Readmission Interval Analysis](#readmission-interval-analysis) (16 queries)
- [Advanced Analytics](#advanced-analytics) (9 queries)

---

## Data Cleaning Queries

### Q1: Schema Inspection
**File**: `01_table_creation_and_data.sql` | **Lines**: 196-199

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'hospital_readmission'
ORDER BY ordinal_position;
```

**What it does**: Retrieves metadata about all columns in the hospital_readmission table

**Business Value**: 
- Documents database schema
- Validates data types before analysis
- Identifies nullable columns for data quality checks

**Output**: 27 rows showing column names, PostgreSQL data types, and null constraints

**When to use**: Start of any data exploration or documentation task

---

### Q2: NULL Value Imputation
**File**: `01_table_creation_and_data.sql` | **Lines**: 202-210

```sql
SELECT 
    patient_id,
    insurance_type,
    household_income as raw_income,
    COALESCE(household_income, 55000) as cleaned_income
FROM hospital_readmission
WHERE household_income IS NULL;
```

**What it does**: Replaces missing income values with $55,000 (median US household income)

**Technical Explanation**:
- `COALESCE(x, y)` returns first non-NULL value
- If household_income is NULL → returns 55000
- If household_income exists → returns actual value

**Business Logic**: 
- Missing financial data is common in healthcare
- Using median prevents bias from outliers
- Maintains data completeness for statistical analysis

**Output**: ~250 rows (5% of dataset with NULL income)

**Data Quality Note**: Creates `cleaned_income` column while preserving original `raw_income` for audit trail

---

### Q3: Text Standardization
**File**: `01_table_creation_and_data.sql` | **Lines**: 212-217

```sql
SELECT DISTINCT
    insurance_type as raw_input,
    INITCAP(LOWER(TRIM(insurance_type))) as standardized_insurance
FROM hospital_readmission;
```

**What it does**: Standardizes insurance type values to consistent capitalization format

**Transformation Pipeline**:
1. `TRIM(insurance_type)` - Removes leading/trailing spaces
2. `LOWER(...)` - Converts to lowercase
3. `INITCAP(...)` - Capitalizes first letter of each word

**Examples**:
- "MEDICARE" → "Medicare"
- "  private insurance  " → "Private Insurance"
- "self-PAY" → "Self-Pay"

**Why this matters**: 
- Prevents duplicate categories due to inconsistent formatting
- Ensures "Medicare" and "MEDICARE" are counted together
- Required for accurate GROUP BY operations

**Output**: 4 distinct insurance types (Medicare, Private, Medicaid, Self-Pay)

---

### Q4: Age Categorization (Derived Column)
**File**: `01_table_creation_and_data.sql` | **Lines**: 221-230

```sql
SELECT 
    patient_id,
    age,
    CASE
        WHEN age < 30  THEN 'Young Age'
        WHEN age BETWEEN 30 AND 60 THEN 'Middle Age'
        WHEN age > 60 THEN 'Senior'
        ELSE 'Unknown' 
    END AS age_bracket
FROM hospital_readmission;
```

**What it does**: Creates age segments for demographic analysis

**Business Rules**:
- **Young Age (< 30)**: Typically healthier, fewer chronic conditions
- **Middle Age (30-60)**: Onset of chronic diseases (diabetes, hypertension)
- **Senior (> 60)**: Higher readmission risk, multiple comorbidities, Medicare eligible

**Clinical Significance**:
- Different age groups have different risk profiles
- Age is a major predictor of readmission
- Medicare vs. Commercial insurance split occurs at age 65

**Use Cases**:
- Age-stratified readmission rates
- Marketing campaigns by demographic
- Resource planning (geriatric vs. general medicine)

**Output**: 5,000 rows with patient_id, numeric age, and categorical age_bracket

---

### Q5: Length of Stay (LOS) Calculation
**File**: `01_table_creation_and_data.sql` | **Lines**: 233-238

```sql
SELECT 
    patient_id,
    admission_date,
    discharge_date,
    (discharge_date - admission_date) as length_of_stay
FROM hospital_readmission;
```

**What it does**: Calculates hospital stay duration in days

**PostgreSQL Date Arithmetic**:
- DATE - DATE = INTEGER (number of days)
- Example: 2024-01-15 - 2024-01-10 = 5 days

**Clinical LOS Benchmarks**:
- **1-3 days**: Observation, minor procedures
- **4-7 days**: Standard medical treatment
- **8-10 days**: Complex cases, post-surgical recovery
- **>10 days**: ICU stays, complications

**Business Impact**:
- Average LOS affects bed turnover rate
- Longer LOS = Higher costs but not always higher revenue
- DRG payments are fixed regardless of LOS

**Use with**: Diagnosis codes to identify LOS outliers per condition

---

### Q6: Multi-Column Imputation with Data Quality Flag
**File**: `01_table_creation_and_data.sql` | **Lines**: 240-251

```sql
SELECT 
    patient_id,
    COALESCE(household_income, 55000) as income,
    COALESCE(comorbidity_score, 0) as comorbidity,
    COALESCE(total_bill_amount, 20000) as bill_amount,
    CASE 
        WHEN COALESCE(household_income, 55000) IS NOT NULL 
        THEN 'Complete'
        ELSE 'Imputed'
    END as data_quality_flag
FROM hospital_readmission;
```

**What it does**: Comprehensive missing value handling across financial and clinical columns

**Imputation Strategy**:
| Column | Default Value | Rationale |
|--------|---------------|-----------|
| household_income | $55,000 | US median household income |
| comorbidity_score | 0 | Assume healthy if unknown |
| total_bill_amount | $20,000 | Average hospital admission cost |

**Data Quality Flag**:
- 'Complete': Original data present
- 'Imputed': At least one field was filled with default value

**Why add the flag?**: 
- Transparency in reporting
- Ability to filter imputed vs. actual data in analysis
- Required for regulatory compliance

**Best Practice**: Always preserve original data in separate column before imputation

---

### Q7: Outlier Detection
**File**: `01_table_creation_and_data.sql` | **Lines**: 253-262

```sql
SELECT 
    patient_id,
    age,
    total_bill_amount
FROM hospital_readmission
WHERE age > 100 OR total_bill_amount > 100000
ORDER BY total_bill_amount DESC;
```

**What it does**: Identifies statistical outliers for validation or removal

**Outlier Thresholds**:
- **age > 100**: Possible data entry error or centenarian (rare)
- **total_bill_amount > $100,000**: Extremely expensive cases

**Possible Causes of High Bills**:
- Extended ICU stay
- Organ transplant
- Major cardiac surgery
- Complications requiring extended hospitalization

**Data Quality Decision Tree**:
1. Review outliers manually
2. Validate with source system
3. Decide: Keep (legitimate), Correct (error), or Remove (invalid)

**Output**: Small subset of records requiring human review

---

### Q8: Duplicate Detection
**File**: `01_table_creation_and_data.sql` | **Lines**: 264-271

```sql
SELECT 
    patient_id,
    admission_date,
    COUNT(*) as duplicate_count
FROM hospital_readmission
GROUP BY patient_id, admission_date
HAVING COUNT(*) > 1;
```

**What it does**: Finds duplicate admission records for same patient on same date

**Business Rule**: Same patient cannot have multiple admissions on exact same date

**Possible Explanations if duplicates found**:
- Data entry error (same admission entered twice)
- Transfer between units recorded as separate admission
- Emergency department visit + inpatient admission on same day

**Action if duplicates found**:
```sql
DELETE FROM hospital_readmission
WHERE id NOT IN (
    SELECT MIN(id)
    FROM hospital_readmission
    GROUP BY patient_id, admission_date
);
```

**Expected Output**: 0 rows (clean dataset)

---

## Basic Aggregation Queries

### Q9: Overall Readmission Rate (Hospital KPI)
**File**: `01_table_creation_and_data.sql` | **Lines**: 273-278

```sql
SELECT 
    COUNT(*) as total_patients,
    SUM(readmitted_30_days) as total_readmissions,
    ROUND(AVG(readmitted_30_days) * 100, 2) as readmission_rate_pct
FROM hospital_readmission;
```

**What it does**: Calculates hospital-wide 30-day readmission rate

**KPI Calculation**:
```
Readmission Rate = (Total Readmissions ÷ Total Admissions) × 100
```

**Why use AVG() instead of SUM()/COUNT()?**
- `readmitted_30_days` is binary (0 or 1)
- AVG of binary column = proportion of 1s
- AVG(readmitted_30_days) = 0.20 = 20%

**Industry Benchmarks**:
- **Excellent**: < 15%
- **Average**: 15-20%
- **Poor**: > 20%

**CMS Penalty**: Hospitals with readmission rates > national average face up to 3% reduction in Medicare payments

**Business Impact**: For 1,000-bed hospital, 1% reduction = $1-3M annual loss

**Output Example**:
```
total_patients: 5000
total_readmissions: 1000
readmission_rate_pct: 20.00%
```

---

### Q10: Readmission by Diagnosis
**File**: `01_table_creation_and_data.sql` | **Lines**: 280-287

```sql
SELECT 
    primary_diagnosis,
    COUNT(*) as total_cases,
    SUM(readmitted_30_days) as readmissions,
    ROUND(AVG(readmitted_30_days) * 100, 1) as readmission_rate
FROM hospital_readmission
GROUP BY primary_diagnosis
ORDER BY readmission_rate DESC;
```

**What it does**: Identifies which medical conditions have highest readmission risk

**Clinical Interpretation**:

**High-Risk Diagnoses** (Expected):
1. **Heart Failure**: 25-30% readmission rate
   - Reason: Fluid management challenges, medication non-adherence
   - Intervention: Daily weight monitoring, telehealth

2. **COPD**: 20-25%
   - Reason: Progressive disease, smoking relapse
   - Intervention: Pulmonary rehabilitation, smoking cessation

3. **Sepsis**: 18-22%
   - Reason: Immune system weakness post-infection
   - Intervention: Extended antibiotic therapy, close monitoring

**Low-Risk Diagnoses**:
- Elective surgery: 5-10%
- Routine procedures: 3-8%

**Business Value**:
- Target interventions for high-risk diagnoses
- Allocate case management resources efficiently
- Develop condition-specific discharge protocols

**Example Output**:
```
| Diagnosis     | Total Cases | Readmissions | Rate  |
|---------------|-------------|--------------|-------|
| Heart Failure | 1000        | 280          | 28.0% |
| COPD          | 750         | 165          | 22.0% |
| Pneumonia     | 650         | 110          | 16.9% |
```

---

### Q11: Revenue by Region
**File**: `01_table_creation_and_data.sql` | **Lines**: 289-296

```sql
SELECT 
    hospital_region,
    COUNT(*) as patient_volume,
    SUM(total_bill_amount) as total_revenue,
    ROUND(AVG(total_bill_amount), 2) as avg_revenue_per_patient
FROM hospital_readmission
GROUP BY hospital_region
ORDER BY total_revenue DESC;
```

**What it does**: Geographic revenue analysis for strategic planning

**Key Metrics**:
- **Patient Volume**: Market size in each region
- **Total Revenue**: Regional contribution to hospital revenue
- **Avg Revenue per Patient**: Revenue efficiency by region

**Strategic Questions**:
1. Which region is most profitable? → Focus marketing
2. Which has lowest avg revenue? → Investigate payer mix or case mix
3. Which has highest volume but low revenue? → Opportunity for service line expansion

**Example Output**:
```
| Region    | Volume | Total Revenue | Avg/Patient |
|-----------|--------|---------------|-------------|
| Northeast | 1500   | $45,000,000   | $30,000     |
| Southeast | 1400   | $38,000,000   | $27,143     |
| Midwest   | 1200   | $32,000,000   | $26,667     |
| West      | 900    | $28,000,000   | $31,111     |
```

**Insight Example**: West has lowest volume but highest avg revenue → Premium services or favorable payer mix

---

### Q12: Insurance Mix Analysis (Payer Penetration)
**File**: `01_table_creation_and_data.sql` | **Lines**: 1142-1153

```sql
SELECT 
    insurance_type,
    COUNT(*) as total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) as market_share
FROM hospital_readmission
GROUP BY insurance_type
ORDER BY total_patients DESC;
```

**What it does**: Analyzes patient payer mix and insurance penetration

**Window Function Explanation**:
- `SUM(COUNT(*)) OVER()`: Total patients across ALL insurance types
- Used in denominator to calculate percentage
- Runs across entire result set (no PARTITION BY)

**Payer Mix Implications**:

| Insurance Type | Reimbursement Rate | Bad Debt Risk | Strategic Value |
|----------------|--------------------|--------------|-----------------|
| Private | 90-100% of charges | Low | High - most profitable |
| Medicare | 60-70% of charges | Very Low | Medium - guaranteed payment |
| Medicaid | 40-60% of charges | Very Low | Low - lowest reimbursement |
| Self-Pay | Varies | Very High | Risky - 40-60% uncollectible |

**Example Output**:
```
| Insurance  | Patients | Market Share |
|------------|----------|--------------|
| Medicare   | 1,750    | 35.0%        |
| Private    | 1,500    | 30.0%        |
| Medicaid   | 1,250    | 25.0%        |
| Self-Pay   | 500      | 10.0%        |
```

**Strategic Insight**: 35% Medicare + 25% Medicaid = 60% government insurance → Need to optimize private payer contracts

---

### Q13: Average LOS by Hospital Type
**File**: `01_table_creation_and_data.sql` | **Lines**: 298-306

```sql
SELECT 
    hospital_type,
    COUNT(*) as admissions,
    ROUND(AVG(discharge_date - admission_date), 1) as avg_los,
    MIN(discharge_date - admission_date) as min_los,
    MAX(discharge_date - admission_date) as max_los
FROM hospital_readmission
GROUP BY hospital_type;
```

**What it does**: Compares operational efficiency across hospital types

**Hospital Classifications**:

**General Hospital**:
- Community hospitals
- Standard cases
- Expected LOS: 4-5 days

**Academic/Teaching Hospital**:
- Complex cases
- Research protocols (may extend LOS)
- Expected LOS: 5-6 days

**Critical Access Hospital (CAH)**:
- Rural, small (<25 beds)
- Limited resources → faster discharge
- Expected LOS: 3-4 days

**LOS Drivers**:
- Case complexity
- Available resources (imaging, specialists)
- Discharge destination availability (SNF beds, home health)

**Benchmark**: If Academic LOS >> General LOS → Investigate teaching inefficiency vs. case mix difference

---

### Q14: Comorbidity Distribution
**File**: `01_table_creation_and_data.sql` | **Lines**: 389-398

```sql
SELECT 
    comorbidity_score,
    COUNT(*) as patient_count,
    ROUND(AVG(readmitted_30_days) * 100, 1) as readmission_rate,
    ROUND(AVG(total_bill_amount), 0) as avg_cost,
    ROUND(AVG(discharge_date - admission_date), 1) as avg_los
FROM hospital_readmission
WHERE comorbidity_score IS NOT NULL
GROUP BY comorbidity_score
ORDER BY comorbidity_score;
```

**What it does**: Analyzes correlation between disease burden and outcomes

**Comorbidity Score (Charlson Index)**:
- Range: 0-24 (higher = more chronic conditions)
- Score 0-2: Minimal disease burden
- Score 3-6: Moderate comorbidity
- Score 7-10: Severe comorbidity
- Score >10: Extremely complex

**Expected Correlations**:
```
↑ Comorbidity Score = ↑ Readmission Rate
↑ Comorbidity Score = ↑ Average Cost
↑ Comorbidity Score = ↑ Length of Stay
```

**Clinical Validation**: Does data show expected patterns?

**Example Output**:
```
| Score | Patients | Readmission Rate | Avg Cost | Avg LOS |
|-------|----------|------------------|----------|---------|
| 0-2   | 1500     | 10.5%            | $15,000  | 3.2 days|
| 3-6   | 2000     | 18.7%            | $22,000  | 4.8 days|
| 7-10  | 1000     | 28.3%            | $35,000  | 6.5 days|
| >10   | 500      | 42.1%            | $55,000  | 9.2 days|
```

---

### Q15: Medication Adherence Impact
**File**: `01_table_creation_and_data.sql` | **Lines**: 400-410

```sql
SELECT 
    CASE 
        WHEN missed_medications = 0 THEN 'Perfect Adherence'
        WHEN missed_medications <= 2 THEN 'Good Adherence'
        WHEN missed_medications <= 4 THEN 'Poor Adherence'
        ELSE 'Critical Non-Adherence'
    END as adherence_level,
    COUNT(*) as patients,
    ROUND(AVG(readmitted_30_days) * 100, 1) as readmission_rate
FROM hospital_readmission
GROUP BY adherence_level
ORDER BY adherence_level;
```

**What it does**: Quantifies medication adherence impact on readmissions

**Adherence Classification**:
- **Perfect (0 missed)**: 100% medication compliance
- **Good (1-2 missed/week)**: 70-85% compliance
- **Poor (3-4 missed/week)**: 40-60% compliance
- **Critical (>4 missed/week)**: <40% compliance

**Clinical Evidence from Research**:
- Perfect adherence: 10-15% readmission rate
- Poor adherence: 25-35% readmission rate
- Non-adherence increases risk by 50-150%

**Common Barriers to Adherence**:
- Cost (can't afford medications)
- Complexity (too many pills, confusing schedule)
- Side effects
- Cognitive impairment (forgot to take)
- Health literacy

**Interventions**:
- Medication reconciliation at discharge
- Simplified regimens (once-daily dosing)
- Pill organizers
- Pharmacy auto-refill programs
- Patient education

**ROI**: Improving adherence from poor to good saves $5,000-10,000 per patient

---

### Q16: ICU Utilization and Cost
**File**: `01_table_creation_and_data.sql` | **Lines**: 412-423

```sql
SELECT 
    CASE 
        WHEN icu_utilization_ratio > 0.5 THEN 'High ICU Use'
        WHEN icu_utilization_ratio > 0.2 THEN 'Moderate ICU Use'
        WHEN icu_utilization_ratio > 0 THEN 'Low ICU Use'
        ELSE 'No ICU'
    END as icu_category,
    COUNT(*) as patient_count,
    ROUND(AVG(readmitted_30_days) * 100, 1) as readmission_rate,
    ROUND(AVG(total_bill_amount), 0) as avg_cost
FROM hospital_readmission
GROUP BY icu_category
ORDER BY icu_category;
```

**What it does**: Analyzes ICU utilization patterns and outcomes

**ICU Ratio Interpretation**:
- icu_utilization_ratio = 0.5 means 50% of stay in ICU
- Example: 10-day stay with 5 days in ICU = 0.5 ratio

**Cost Context**:
- **ICU**: $3,000-10,000/day
- **Regular floor**: $1,000-2,000/day
- **Step-down unit**: $1,500-3,000/day

**Clinical Patterns**:
- High ICU use typically indicates severe illness
- May correlate with higher readmission risk
- But also may indicate appropriate intensive monitoring

**Paradox**: High ICU use could mean:
1. Very sick patients → high readmission risk, OR
2. Excellent monitoring → lower readmission risk

**Analysis**: Compare readmission rates between high vs. no ICU to determine which effect dominates

---

### Q17: Revenue by Insurance Type (Payer Profitability)
**File**: `01_table_creation_and_data.sql` | **Lines**: 435-445

```sql
SELECT 
    insurance_type,
    COUNT(*) as patients,
    ROUND(AVG(total_bill_amount), 0) as avg_bill,
    ROUND(AVG(out_of_pocket_ratio), 3) as avg_oop_ratio,
    ROUND(AVG(total_bill_amount * out_of_pocket_ratio), 0) as avg_patient_payment,
    ROUND(AVG(total_bill_amount * (1 - out_of_pocket_ratio)), 0) as avg_insurance_payment
FROM hospital_readmission
WHERE total_bill_amount IS NOT NULL
GROUP BY insurance_type
ORDER BY avg_insurance_payment DESC;
```

**What it does**: Breaks down revenue sources by payer type

**Key Calculations**:
- `avg_bill`: Average total charges per patient
- `avg_oop_ratio`: Average % patient pays out-of-pocket
- `avg_patient_payment`: Patient responsibility
- `avg_insurance_payment`: Insurance reimbursement

**Example Calculation**:
```
Total Bill: $30,000
OOP Ratio: 0.20 (20%)
Patient Payment: $30,000 × 0.20 = $6,000
Insurance Payment: $30,000 × 0.80 = $24,000
```

**Strategic Insights**:
- Which payer has highest reimbursement?
- Which requires most patient cost-sharing?
- Balance volume vs. profitability

**Example Output**:
```
| Insurance | Patients | Avg Bill | OOP Ratio | Patient Pays | Insurance Pays |
|-----------|----------|----------|-----------|--------------|----------------|
| Private   | 1500     | $32,000  | 0.180     | $5,760       | $26,240        |
| Medicare  | 1750     | $28,000  | 0.200     | $5,600       | $22,400        |
| Medicaid  | 1250     | $26,000  | 0.050     | $1,300       | $24,700        |
| Self-Pay  | 500      | $25,000  | 1.000     | $25,000      | $0             |
```

---

### Q18: Monthly Admission Trends
**File**: `01_table_creation_and_data.sql` | **Lines**: 447-458

```sql
SELECT 
    EXTRACT(MONTH FROM admission_date) as month,
    TO_CHAR(admission_date, 'Month') as month_name,
    COUNT(*) as admissions,
    ROUND(AVG(readmitted_30_days) * 100, 1) as readmission_rate
FROM hospital_readmission
GROUP BY EXTRACT(MONTH FROM admission_date), TO_CHAR(admission_date, 'Month')
ORDER BY EXTRACT(MONTH FROM admission_date);
```

**What it does**: Identifies seasonal patterns in healthcare utilization

**PostgreSQL Date Functions**:
- `EXTRACT(MONTH FROM date)`: Returns 1-12
- `TO_CHAR(date, 'Month')`: Returns month name (January, February...)

**Typical Seasonal Patterns**:

**Winter (December-February)**:
- ↑ Pneumonia (cold weather, indoor crowding)
- ↑ Heart attacks (cold stress on cardiovascular system)
- ↑ Flu-related admissions
- Highest admission volumes

**Spring (March-May)**:
- ↓ Overall admissions
- ↑ Allergy-related issues

**Summer (June-August)**:
- ↑ Trauma (outdoor activities, accidents)
- ↑ Heat-related illness
- ↓ Elective surgery (vacation season)

**Fall (September-November)**:
- ↑ COPD exacerbations (weather changes)
- ↑ Elective surgeries (before insurance deductibles reset)

**Operational Planning**:
- Staff up in winter months
- Schedule maintenance/remodeling in summer
- Predict cash flow based on seasonal volume

---

### Q19: Age and Income Distribution
**File**: `01_table_creation_and_data.sql` | **Lines**: 460-471

```sql
SELECT 
    CASE 
        WHEN age < 40 THEN 'Under 40'
        WHEN age BETWEEN 40 AND 64 THEN '40-64 (Working Age)'
        ELSE '65+ (Medicare Age)'
    END as age_group,
    CASE 
        WHEN household_income < 30000 THEN 'Low Income'
        WHEN household_income BETWEEN 30000 AND 75000 THEN 'Middle Income'
        ELSE 'High Income'
    END as income_level,
    COUNT(*) as patient_count,
    ROUND(AVG(readmitted_30_days) * 100, 1) as readmission_rate
FROM hospital_readmission
WHERE household_income IS NOT NULL
GROUP BY age_group, income_level
ORDER BY age_group, income_level;
```

**What it does**: Cross-tabulation of age and income to identify vulnerable populations

**Social Determinants Framework**:
- Age affects health status
- Income affects healthcare access
- Combined effect compounds disparities

**High-Risk Groups**:
1. **Low Income + Senior**: Fixed income, Medicare gaps, can't afford supplements
2. **Low Income + Working Age**: Uninsured/underinsured, delay care
3. **Middle Income + Senior**: Better than low income but still face cost barriers

**Policy Implications**:
- Target financial assistance programs
- Address social determinants (transportation, food insecurity)
- Develop sliding-scale payment plans

**Example Output**:
```
| Age Group         | Income Level  | Patients | Readmission Rate |
|-------------------|---------------|----------|------------------|
| Under 40          | Low Income    | 200      | 22.5%            |
| Under 40          | Middle Income | 450      | 15.2%            |
| 40-64 (Working)   | Low Income    | 350      | 28.7%            |
| 65+ (Medicare)    | Low Income    | 600      | 32.1%            |
| 65+ (Medicare)    | High Income   | 400      | 18.3%            |
```

---

### Q20: Diagnosis by Region
**File**: `01_table_creation_and_data.sql` | **Lines**: 473-482

```sql
SELECT 
    hospital_region,
    primary_diagnosis,
    COUNT(*) as case_count,
    ROUND(AVG(total_bill_amount), 0) as avg_cost
FROM hospital_readmission
GROUP BY hospital_region, primary_diagnosis
ORDER BY hospital_region, case_count DESC;
```

**What it does**: Identifies regional variations in disease prevalence

**Geographic Health Disparities**:
- Northeast: ↑ Heart disease (diet, stress)
- Southeast: ↑ Diabetes (obesity, "stroke belt")
- Midwest: ↑ COPD (manufacturing, smoking)
- West: Different case mix (younger, healthier population)

**Business Applications**:
1. **Service Line Planning**: Build cardiac center in high-heart-disease region
2. **Physician Recruitment**: Hire specialists for prevalent conditions
3. **Marketing**: Target prevention campaigns to regional disease patterns

**Example Output**:
```
| Region    | Diagnosis     | Cases | Avg Cost |
|-----------|---------------|-------|----------|
| Southeast | Diabetes      | 350   | $28,000  |
| Southeast | Heart Failure | 280   | $35,000  |
| Northeast | MI            | 220   | $42,000  |
| Midwest   | COPD          | 300   | $25,000  |
```

---

## Window Function Queries

### Q21: Patient Spending Rank
**File**: `01_table_creation_and_data.sql` | **Lines**: 308-316

```sql
SELECT 
    patient_id,
    total_bill_amount,
    RANK() OVER(ORDER BY total_bill_amount DESC) as spending_rank,
    DENSE_RANK() OVER(ORDER BY total_bill_amount DESC) as dense_rank
FROM hospital_readmission
WHERE total_bill_amount IS NOT NULL
ORDER BY total_bill_amount DESC
LIMIT 20;
```

**What it does**: Ranks patients by total spending (identifies high-cost outliers)

**Window Function Comparison**:

**RANK()**:
- Assigns same rank to ties
- Skips ranks after ties
- Example: 1, 2, 2, 4, 5 (rank 3 is skipped)

**DENSE_RANK()**:
- Assigns same rank to ties
- NO gaps in ranking
- Example: 1, 2, 2, 3, 4 (no skipping)

**When to use RANK vs DENSE_RANK**:
- Use RANK() for "top N" queries (top 10 patients)
- Use DENSE_RANK() for percentile analysis (top 5% of spenders)

**Business Application**: 
- Identify top 1% of spenders for intensive case management
- Pareto Principle: 80% of costs from 20% of patients
- Target high-utilizers for care coordination

**Example Output**:
```
| patient_id | total_bill | spending_rank | dense_rank |
|------------|------------|---------------|------------|
| PAT02344   | $125,000   | 1             | 1          |
| PAT01892   | $118,000   | 2             | 2          |
| PAT03421   | $118,000   | 2             | 2          |
| PAT00876   | $112,000   | 4             | 3          | ← Note rank 3 skipped
```

---

### Q22: Running Total Revenue
**File**: `01_table_creation_and_data.sql` | **Lines**: 318-326

```sql
SELECT 
    admission_date,
    total_bill_amount,
    SUM(total_bill_amount) OVER(
        ORDER BY admission_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_total
FROM hospital_readmission
ORDER BY admission_date;
```

**What it does**: Calculates cumulative revenue over time

**Window Frame Explanation**:
- `UNBOUNDED PRECEDING`: Start from first row in ordered set
- `CURRENT ROW`: Include current row
- Result: Sum of all rows from beginning up to current row

**Visual Example**:
```
| Date       | Bill   | Running Total |
|------------|--------|---------------|
| 2024-01-01 | $1,000 | $1,000        | ← First row
| 2024-01-02 | $2,000 | $3,000        | ← 1,000 + 2,000
| 2024-01-03 | $1,500 | $4,500        | ← 3,000 + 1,500
| 2024-01-04 | $3,000 | $7,500        | ← 4,500 + 3,000
```

**Business Applications**:
1. **Revenue Tracking**: Monitor progress toward annual budget target
2. **Forecasting**: Project end-of-year revenue based on trend
3. **Goal Setting**: Identify when monthly/quarterly targets are met

**Alternative Syntax (Simpler)**:
```sql
SUM(total_bill_amount) OVER(ORDER BY admission_date)
-- Default frame is UNBOUNDED PRECEDING to CURRENT ROW
```

---

### Q23: Patient Visit Sequencing
**File**: `01_table_creation_and_data.sql` | **Lines**: 328-336

```sql
SELECT 
    patient_id,
    admission_date,
    ROW_NUMBER() OVER(PARTITION BY patient_id ORDER BY admission_date) as visit_number,
    LAG(admission_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_visit,
    LEAD(admission_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as next_visit
FROM hospital_readmission
ORDER BY patient_id, admission_date;
```

**What it does**: Tracks patient care continuity and visit patterns

**Window Functions Breakdown**:

**ROW_NUMBER()**:
- Sequential numbering within each patient
- 1, 2, 3, 4... for each patient's visits

**LAG(admission_date)**:
- Gets previous admission date
- NULL for first visit (no previous)

**LEAD(admission_date)**:
- Gets next admission date
- NULL for last visit (no future visit yet)

**PARTITION BY patient_id**:
- Separate calculation for each patient
- PAT00001's visits don't affect PAT00002's numbering

**Example Output**:
```
| patient_id | admission_date | visit_number | prev_visit | next_visit |
|------------|----------------|--------------|------------|------------|
| PAT00001   | 2024-01-15     | 1            | NULL       | 2024-03-20 |
| PAT00001   | 2024-03-20     | 2            | 2024-01-15 | 2024-05-10 |
| PAT00001   | 2024-05-10     | 3            | 2024-03-20 | NULL       |
| PAT00002   | 2024-02-18     | 1            | NULL       | NULL       |
```

**Use Cases**:
- Identify "frequent flyer" patients (high visit_number)
- Calculate days between visits (admission_date - prev_visit)
- Predict next visit timing using LEAD()

---

### Q24: Cost Percentiles (NTILE)
**File**: `01_table_creation_and_data.sql` | **Lines**: 338-346

```sql
SELECT 
    patient_id,
    total_bill_amount,
    NTILE(4) OVER(ORDER BY total_bill_amount) as quartile,
    NTILE(10) OVER(ORDER BY total_bill_amount) as decile,
    NTILE(100) OVER(ORDER BY total_bill_amount) as percentile
FROM hospital_readmission
WHERE total_bill_amount IS NOT NULL;
```

**What it does**: Segments patients into equal-sized cost-based groups

**NTILE(n)** divides ordered data into n equal buckets:

**NTILE(4) - Quartiles**:
- Q1: Bottom 25% (lowest cost)
- Q2: 25-50%
- Q3: 50-75%
- Q4: Top 25% (highest cost)

**NTILE(10) - Deciles**:
- D1: Bottom 10%
- D10: Top 10%

**NTILE(100) - Percentiles**:
- P1: Bottom 1%
- P99: Top 1%

**Distribution Example** (5000 patients):
```
| Quartile | Patients | Cost Range      |
|----------|----------|-----------------|
| Q1       | 1,250    | $10,000-15,000  |
| Q2       | 1,250    | $15,001-22,000  |
| Q3       | 1,250    | $22,001-32,000  |
| Q4       | 1,250    | $32,001-150,000 |
```

**Business Applications**:
1. **Target High-Cost Patients**: Focus on Q4 or top decile
2. **Efficient Patients**: Benchmark against Q1 (low-cost, good outcomes)
3. **Tiered Interventions**: Different programs for each quartile

**Query to Analyze Quartiles**:
```sql
WITH cost_quartiles AS (
    SELECT *, NTILE(4) OVER(ORDER BY total_bill_amount) as quartile
    FROM hospital_readmission
)
SELECT 
    quartile,
    MIN(total_bill_amount) as min_cost,
    MAX(total_bill_amount) as max_cost,
    AVG(total_bill_amount) as avg_cost
FROM cost_quartiles
GROUP BY quartile;
```

---

### Q25: 7-Day Moving Average (Smoothing)
**File**: `01_table_creation_and_data.sql` | **Lines**: 348-358

```sql
SELECT 
    admission_date,
    COUNT(*) as daily_admissions,
    AVG(COUNT(*)) OVER(
        ORDER BY admission_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as moving_avg_7day
FROM hospital_readmission
GROUP BY admission_date
ORDER BY admission_date;
```

**What it does**: Smooths daily admission fluctuations to identify trends

**Window Frame**:
- `6 PRECEDING`: Previous 6 days
- `CURRENT ROW`: Today
- Total: 7 days (today + previous 6)

**Why Use Moving Averages?**:
- Daily data is noisy (random variation)
- 7-day average removes "day of week" effect
- Reveals underlying trends

**Visual Example**:
```
| Date       | Daily Admissions | 7-Day Avg |
|------------|------------------|-----------|
| 2024-01-01 | 15               | 15.0      | ← Only 1 day
| 2024-01-02 | 18               | 16.5      | ← Average of 2 days
| 2024-01-03 | 22               | 18.3      | ← Average of 3 days
...
| 2024-01-07 | 19               | 18.7      | ← First true 7-day avg
| 2024-01-08 | 21               | 19.4      | ← Drops day 1, adds day 8
```

**Operations Applications**:
1. **Capacity Planning**: Use 7-day avg to staff appropriately
2. **Trend Detection**: Rising avg = increasing volume
3. **Anomaly Detection**: Daily count >> 7-day avg = unusual spike

**Alternative: 30-Day Moving Average** (for longer trends):
```sql
ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
```

---

### Q26: Year-over-Year Growth
**File**: `01_table_creation_and_data.sql` | **Lines**: 360-372

```sql
SELECT 
    DATE_TRUNC('month', admission_date) as month,
    COUNT(*) as monthly_admissions,
    LAG(COUNT(*), 12) OVER(ORDER BY DATE_TRUNC('month', admission_date)) as same_month_last_year,
    COUNT(*) - LAG(COUNT(*), 12) OVER(ORDER BY DATE_TRUNC('month', admission_date)) as yoy_change,
    ROUND(
        (COUNT(*) - LAG(COUNT(*), 12) OVER(ORDER BY DATE_TRUNC('month', admission_date))) * 100.0 
        / LAG(COUNT(*), 12) OVER(ORDER BY DATE_TRUNC('month', admission_date)),
        2
    ) as yoy_pct_change
FROM hospital_readmission
GROUP BY DATE_TRUNC('month', admission_date)
ORDER BY month;
```

**What it does**: Compares monthly metrics to same month previous year

**LAG(COUNT(*), 12)**:
- Goes back 12 rows (12 months)
- Gets count from exactly 1 year ago
- Example: Jan 2024 is compared to Jan 2023

**Why Compare YoY (not month-to-month)?**:
- Removes seasonal variation
- Jan vs. Dec comparison is misleading (holidays affect both differently)
- Jan vs. Jan is apples-to-apples

**Metrics Calculated**:
1. **yoy_change**: Absolute difference (e.g., +50 admissions)
2. **yoy_pct_change**: Percentage growth (e.g., +5.2%)

**Example Output**:
```
| Month    | Current | Last Year | YoY Change | YoY % |
|----------|---------|-----------|------------|-------|
| Jan 2024 | 450     | 420       | +30        | +7.1% |
| Feb 2024 | 430     | 410       | +20        | +4.9% |
| Mar 2024 | 410     | 450       | -40        | -8.9% | ← Declining!
```

**Strategic Use**:
- **Positive growth**: Market expansion, new service lines succeeding
- **Negative growth**: Market contraction, competition, quality issues
- Track over 24+ months to identify multi-year trends

---

### Q27: Cumulative Distribution (CUME_DIST)
**File**: `01_table_creation_and_data.sql` | **Lines**: 1108-1116

```sql
SELECT 
    patient_id,
    total_bill_amount,
    CUME_DIST() OVER(ORDER BY total_bill_amount) as cdf
FROM hospital_readmission;
```

**What it does**: Calculates what % of patients spent less than or equal to current patient

**CUME_DIST() Formula**:
```
CDF = (Number of rows with value ≤ current) / Total rows
```

**Example Calculation**:
```
| patient_id | bill    | cdf   | Interpretation              |
|------------|---------|-------|-----------------------------|
| PAT00001   | $10,000 | 0.05  | 5% of patients spent ≤$10K  |
| PAT00002   | $25,000 | 0.50  | 50% spent ≤$25K (median)    |
| PAT00003   | $50,000 | 0.90  | 90% spent ≤$50K             |
| PAT00004   | $100,000| 0.99  | Top 1% of spenders          |
```

**Business Questions Answered**:

**Q: "What bill amount represents the 80th percentile?"**
```sql
SELECT MIN(total_bill_amount)
FROM (SELECT *, CUME_DIST() OVER(ORDER BY total_bill_amount) as cdf FROM hospital_readmission)
WHERE cdf >= 0.80;
```

**Q: "How many patients are in the top 10% of spenders?"**
```sql
SELECT COUNT(*)
FROM (SELECT *, CUME_DIST() OVER(ORDER BY total_bill_amount) as cdf FROM hospital_readmission)
WHERE cdf > 0.90;
```

**Pareto Analysis**:
```sql
-- Find bill amount threshold for top 20%
SELECT MIN(total_bill_amount) FROM (...)
WHERE cdf >= 0.80;

-- Then target these high-cost patients for case management
```

---

## Clinical Risk Analysis Queries

### Q28: High-Risk Patient Identification
**File**: `01_table_creation_and_data.sql` | **Lines**: 374-387

```sql
SELECT 
    patient_id, age, comorbidity_score, missed_medications, readmitted_30_days,
    CASE 
        WHEN comorbidity_score > 10 AND missed_medications > 3 THEN 'Critical Risk'
        WHEN comorbidity_score > 7 OR missed_medications > 2 THEN 'High Risk'
        WHEN comorbidity_score > 3 OR age > 75 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END as risk_category
FROM hospital_readmission
WHERE readmitted_30_days = 1
ORDER BY comorbidity_score DESC, missed_medications DESC;
```

**What it does**: Stratifies readmitted patients by risk level for targeted interventions

**Risk Scoring Logic**:

**Critical Risk** (Immediate Intervention):
- Comorbidity > 10 (severe chronic disease burden)
- AND missed medications > 3/week (poor adherence)
- **Action**: Assign case manager, daily check-ins, medication management

**High Risk** (Close Monitoring):
- Comorbidity 7-10 OR missed medications 2-3/week
- **Action**: Weekly nurse calls, telehealth monitoring

**Moderate Risk** (Standard Follow-up):
- Comorbidity 3-7 OR age > 75
- **Action**: 2-week follow-up appointment, standard transitional care

**Low Risk** (Routine Care):
- All other patients
- **Action**: Routine post-discharge call

**Why Filter by `readmitted_30_days = 1`?**:
- Focus on patients who ALREADY readmitted
- Retrospective analysis to validate risk model
- Learn which factors predicted actual readmissions

**Validation Query**:
```sql
-- Does risk model predict actual readmissions?
SELECT risk_category, 
       COUNT(*) as total,
       SUM(readmitted_30_days) as readmissions,
       AVG(readmitted_30_days) * 100 as readmission_rate
FROM (above query)
GROUP BY risk_category;
```

---

### Q29: Young High-Risk Patients (Genetic/Lifestyle Red Flags)
**File**: `01_table_creation_and_data.sql` | **Lines**: 1179-1192

```sql
SELECT 
    patient_id,
    age,
    primary_diagnosis,
    comorbidity_score
FROM hospital_readmission
WHERE age < 40 
  AND comorbidity_score > 4
ORDER BY comorbidity_score DESC;
```

**What it does**: Identifies young patients with unusually high disease burden

**Clinical Significance**:

**Normal**:
- 80-year-old with comorbidity score 10 = expected (age-related diseases)

**Abnormal Red Flags**:
- 25-year-old with comorbidity score 6 = highly unusual
- 35-year-old with comorbidity score 8 = requires investigation

**Possible Causes**:

1. **Genetic Disorders**:
   - Familial hypercholesterolemia
   - Inherited cardiac conditions (hypertrophic cardiomyopathy)
   - Genetic kidney disease

2. **Lifestyle Factors**:
   - Morbid obesity (BMI >40)
   - Substance abuse
   - Severe untreated mental illness

3. **Chronic Disease Early Onset**:
   - Type 1 diabetes with complications
   - Autoimmune disorders (lupus, rheumatoid arthritis)
   - Early-onset cardiovascular disease

**Interventions**:
- Genetic counseling referral
- Intensive lifestyle modification programs
- Psychosocial support
- Family planning counseling
- Early aggressive treatment

**Example Output**:
```
| patient_id | age | diagnosis      | comorbidity_score |
|------------|-----|----------------|-------------------|
| PAT02341   | 28  | Heart Failure  | 9                 | ← Highly unusual
| PAT01892   | 35  | Diabetes       | 7                 |
| PAT03421   | 32  | COPD           | 6                 |
```

---

### Q30: Wealth-Health Paradox
**File**: `01_table_creation_and_data.sql` | **Lines**: 1194-1208

```sql
SELECT 
    CASE 
        WHEN household_income > 100000 THEN 'Wealthy'
        WHEN household_income < 30000 THEN 'Low Income'
        ELSE 'Middle Class'
    END as income_class,
    ROUND(AVG(comorbidity_score), 2) as avg_sickness_score,
    ROUND(AVG(age), 0) as avg_age
FROM hospital_readmission
GROUP BY 1
ORDER BY avg_sickness_score DESC;
```

**What it does**: Tests correlation between socioeconomic status and health outcomes

**Social Determinants of Health (SDOH)**:

**Hypothesis**: 
- Higher income → Better health (access to care, nutrition, preventive services)
- Lower income → Worse health (delayed care, chronic stress, poor nutrition)

**Expected Findings**:
```
| Income Class | Avg Comorbidity | Avg Age |
|--------------|----------------|---------|
| Low Income   | 8.5            | 62      | ← Highest disease burden
| Middle Class | 6.2            | 58      |
| Wealthy      | 4.1            | 55      | ← Lowest disease burden
```

**Why Low Income = Worse Health?**:

1. **Healthcare Access**:
   - Uninsured/underinsured
   - Can't afford copays
   - Skip medications due to cost

2. **Nutrition**:
   - Food insecurity
   - Limited access to fresh produce ("food deserts")
   - Higher consumption of processed foods

3. **Environment**:
   - Unsafe neighborhoods (stress, violence)
   - Poor housing quality
   - Exposure to environmental toxins

4. **Chronic Stress**:
   - Financial insecurity
   - Job instability
   - Impacts cortisol levels → inflammation → disease

**Policy Implications**:
- Address SDOH to improve population health
- Financial assistance programs
- Transportation services
- Food banks/nutrition programs
- Care coordination for vulnerable populations

---

### Q31: Complex Chronic Disease Patients
**File**: `01_table_creation_and_data.sql` | **Lines**: 1155-1165

```sql
SELECT 
    COUNT(*) as complex_patients,
    ROUND(AVG(total_bill_amount), 0) as avg_cost
FROM hospital_readmission
WHERE primary_diagnosis LIKE '%Hypertension%'
  AND comorbidity_score >= 3;
```

**What it does**: Identifies patients with multiple chronic conditions

**Complexity Criteria**:
- **Primary diagnosis**: Hypertension (high blood pressure)
- **PLUS** comorbidity score ≥ 3 (at least 3 additional conditions)

**Why This Population Matters**:

**Cost Concentration**:
- 5% of patients with complex chronic disease
- Consume 50% of total healthcare spending
- Frequent ED visits, hospitalizations, specialist care

**Care Challenges**:
1. **Polypharmacy**: 10+ medications → drug interactions, adherence issues
2. **Multiple Specialists**: Cardiologist, nephrologist, endocrinologist → fragmented care
3. **High Readmission Risk**: Difficult to stabilize multiple conditions
4. **Social Needs**: Often have transportation, financial, caregiver needs

**Typical Profile**:
- 68-year-old with:
  - Hypertension (primary)
  - Diabetes (comorbidity 1)
  - Chronic kidney disease (comorbidity 2)
  - COPD (comorbidity 3)
  - Depression (comorbidity 4)

**Care Model Solutions**:

1. **Patient-Centered Medical Home (PCMH)**:
   - Primary care physician coordinates all care
   - Care team (nurse, pharmacist, social worker)

2. **Accountable Care Organization (ACO)**:
   - Shared savings model
   - Incentivizes keeping patients healthy

3. **Chronic Care Management (CCM)**:
   - Monthly care coordination calls
   - Medication reconciliation
   - Care plan development

**ROI**: Every $1 spent on care coordination saves $3-5 in avoidable hospitalizations

---

### Q32: Multi-System Failure Detection
**File**: `01_table_creation_and_data.sql` | **Lines**: 1167-1177

```sql
SELECT 
    patient_id,
    COUNT(DISTINCT primary_diagnosis) as unique_conditions
FROM hospital_readmission
GROUP BY patient_id
HAVING COUNT(DISTINCT primary_diagnosis) > 1
ORDER BY unique_conditions DESC;
```

**What it does**: Finds patients with admissions for different organ systems

**Clinical Significance**:

**Single-System Disease** (Lower Risk):
- Patient with 3 admissions ALL for COPD
- Indicates stable chronic disease with exacerbations
- Manageable with disease-specific protocol

**Multi-System Failure** (Higher Risk):
- Patient with admissions for:
  1. Heart Failure (cardiovascular system)
  2. Pneumonia (respiratory system)
  3. Sepsis (immune system)
  4. Stroke (neurological system)
- Indicates **systemic deterioration**
- Much higher mortality and readmission risk

**Why Multi-System is Dangerous**:
- Cascading failures: Heart failure → lung congestion → pneumonia → sepsis
- Harder to treat: Medications for one condition may worsen another
- Complex care coordination needed

**Example Output**:
```
| patient_id | unique_conditions | Diagnoses                          |
|------------|-------------------|------------------------------------|
| PAT00234   | 5                 | Heart Failure, Diabetes, Sepsis... |
| PAT01892   | 4                 | MI, Pneumonia, Stroke, COPD        |
| PAT02341   | 3                 | Heart Failure, Sepsis, Diabetes    |
```

**Action for Multi-System Patients**:
- Palliative care consult
- Goals of care discussion
- Intensive case management
- Geriatrics or complex care clinic referral

---

### Q33: Predictive Risk Score Algorithm
**File**: `01_table_creation_and_data.sql` | **Lines**: 1280-1321

```sql
WITH RiskCalc AS (
    SELECT 
        patient_id, age, primary_diagnosis,
        (
            CASE WHEN age > 70 THEN 20 ELSE 0 END +
            CASE WHEN primary_diagnosis LIKE '%Heart Failure%' THEN 30 ELSE 0 END +
            CASE WHEN admission_type = 'Emergency' THEN 10 ELSE 0 END +
            CASE WHEN calculate_lace(...) > 10 THEN 40 ELSE 0 END +
            (COALESCE(comorbidity_score, 0) * 5)
        ) as predictive_risk_score
    FROM hospital_readmission
)
SELECT 
    patient_id, age, primary_diagnosis, predictive_risk_score,
    CASE 
        WHEN predictive_risk_score >= 80 THEN '🔴 High Risk'
        WHEN predictive_risk_score >= 50 THEN '🟡 Medium Risk'
        ELSE '🟢 Low Risk'
    END as risk_category
FROM RiskCalc
ORDER BY predictive_risk_score DESC;
```

**What it does**: Creates composite risk score for discharge planning decisions

**Risk Scoring Components** (Additive Model):

| Factor | Points | Clinical Rationale |
|--------|--------|--------------------|
| Age > 70 | +20 | Increased frailty, polypharmacy, fall risk |
| Heart Failure diagnosis | +30 | Highest readmission rate condition (25-30%) |
| Emergency admission | +10 | Indicates acute instability vs. planned care |
| LACE Score > 10 | +40 | Validated readmission predictor |
| Comorbidity Score | ×5 per point | Disease burden multiplier |

**LACE Score** (referenced in formula):
- **L**ength of stay (>7 days = higher risk)
- **A**cuity of admission (emergency = higher risk)
- **C**omorbidity index (Charlson score)
- **E**mergency dept visits in past 6 months

**Score Interpretation**:

**Score 0-49 (Low Risk)**:
- Standard discharge planning
- Follow-up in 2-4 weeks
- Patient education materials

**Score 50-79 (Medium Risk)**:
- Enhanced discharge planning
- Home health referral
- Follow-up call within 48 hours
- 1-week follow-up appointment

**Score ≥80 (High Risk)**:
- Intensive transitional care
- Case manager assigned
- Daily check-ins for first week
- Medication reconciliation by pharmacist
- Transportation assistance
- 24-48 hour follow-up appointment

**Example Calculation**:
```
85-year-old with Heart Failure, emergency admission, comorbidity score 8:
  Age >70: +20
  Heart Failure: +30
  Emergency: +10
  Comorbidity 8: +40 (8×5)
  Total: 100 points = 🔴 HIGH RISK
```

**Validation**:
```sql
-- Test if risk score predicts actual readmissions
SELECT risk_category,
       COUNT(*) as patients,
       SUM(readmitted_30_days) as readmissions,
       AVG(readmitted_30_days)*100 as readmission_rate
FROM (above query)
GROUP BY risk_category;

-- Expected: Higher scores should have higher readmission rates
```

---

## Readmission Interval Analysis Queries

### Q34: Days Between Discharge and Readmission (Basic)
**File**: `readmission_intervals_fixed.sql` | **Lines**: 27-34

```sql
SELECT 
    patient_id,
    admission_date,
    LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_date,
    admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
FROM hospital_readmission
ORDER BY patient_id, admission_date;
```

**What it does**: Calculates time elapsed between discharge and next admission

**Window Function Breakdown**:

1. **PARTITION BY patient_id**: 
   - Separate calculation for each patient
   - PAT00001's gaps don't mix with PAT00002's

2. **ORDER BY admission_date**:
   - Chronological order (oldest → newest)

3. **LAG(discharge_date)**:
   - Gets discharge date from PREVIOUS row
   - Returns NULL for first admission (no previous discharge)

4. **admission_date - LAG(discharge_date)**:
   - PostgreSQL date arithmetic
   - DATE - DATE = INTEGER (days)

**Output Interpretation**:

```
| patient_id | admission_date | prev_discharge_date | days_gap |
|------------|----------------|---------------------|----------|
| PAT00001   | 2024-01-15     | NULL                | NULL     | ← First admission
| PAT00001   | 2024-03-20     | 2024-01-24          | 55       | ← 55 days after discharge
| PAT00001   | 2024-05-10     | 2024-03-29          | 42       | ← 42 days gap
| PAT00002   | 2024-02-18     | NULL                | NULL     | ← First admission
| PAT00002   | 2024-04-25     | 2024-02-28          | 56       | ← 56 days gap
```

**Clinical Interpretation**:
- days_gap = 5 → Very fast readmission (HIGH RISK)
- days_gap = 55 → Slower readmission (MODERATE RISK)
- days_gap = NULL → First visit (not a readmission)

**Use Cases**:
- Identify rapid readmissions (≤30 days) for intervention
- Calculate average time to readmission by diagnosis
- Track readmission trends over time

---

### Q35: Readmission Risk Stratification
**File**: `readmission_intervals_fixed.sql` | **Lines**: 94-117

```sql
SELECT 
    patient_id,
    admission_date,
    LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge_date,
    admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap,
    readmitted_30_days,
    CASE 
        WHEN admission_date - LAG(discharge_date) OVER(...) <= 7 
             THEN '🚨 CRITICAL (≤7 days)'
        WHEN admission_date - LAG(discharge_date) OVER(...) <= 14 
             THEN '🔴 HIGH RISK (8-14 days)'
        WHEN admission_date - LAG(discharge_date) OVER(...) <= 30 
             THEN '🟡 MODERATE RISK (15-30 days)'
        WHEN admission_date - LAG(discharge_date) OVER(...) IS NULL 
             THEN '🆕 First Visit'
        ELSE '🟢 LOW RISK (30+ days)'
    END as readmission_risk_level
FROM hospital_readmission
WHERE admission_date - LAG(discharge_date) OVER(...) IS NOT NULL
   OR LAG(discharge_date) OVER(...) IS NULL
ORDER BY patient_id, admission_date;
```

**What it does**: Categorizes readmissions by clinical urgency based on timing

**Risk Tier Definitions**:

**🚨 CRITICAL (≤7 days)**
- **Clinical Meaning**: Patient was NOT ready for discharge
- **Root Causes**: 
  - Premature discharge (financial pressure to free bed)
  - Unresolved complications
  - Inadequate discharge planning
  - Patient sent home without proper support
- **Action Required**: 
  - Urgent case manager review
  - Physician peer review (was discharge appropriate?)
  - Root cause analysis

**🔴 HIGH RISK (8-14 days)**
- **Clinical Meaning**: Discharge planning was inadequate
- **Root Causes**:
  - Medication errors (wrong dose, drug interactions)
  - Missed follow-up appointments
  - Patient non-compliance
  - Lack of caregiver support
- **Action Required**:
  - Case manager follow-up call within 24 hours
  - Medication reconciliation
  - Schedule urgent follow-up appointment

**🟡 MODERATE RISK (15-30 days)**
- **Clinical Meaning**: Preventable readmission with better coordination
- **Root Causes**:
  - No home health services
  - Missed primary care follow-up
  - Ran out of medications
  - Social determinants (no transportation, food insecurity)
- **Action Required**:
  - Standard transitional care program
  - Social work consult
  - 2-week follow-up appointment

**🟢 LOW RISK (>30 days)**
- **Clinical Meaning**: New acute event (less likely preventable)
- **Root Causes**:
  - New medical problem unrelated to prior admission
  - Trauma/accident
  - Progression of chronic disease
- **Action Required**:
  - Monitor for patterns only
  - Standard care

**CMS Penalty Threshold**: 30-day readmissions incur financial penalties ($1-3M annually for typical hospital)

**Example Output**:
```
| patient_id | admission_date | days_gap | risk_level              |
|------------|----------------|----------|-------------------------|
| PAT00001   | 2024-03-20     | 55       | 🟢 LOW RISK (30+ days) |
| PAT00002   | 2024-05-12     | 7        | 🚨 CRITICAL (≤7 days)  |
| PAT00003   | 2024-06-18     | 10       | 🔴 HIGH RISK (8-14)    |
```

---

### Q36: Readmission Window Distribution
**File**: `readmission_intervals_fixed.sql` | **Lines**: 136-162

```sql
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
    SELECT patient_id,
        admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
    FROM hospital_readmission
) gaps
WHERE days_gap IS NOT NULL
GROUP BY readmission_window
ORDER BY CASE 
    WHEN readmission_window = '≤7 days (Critical)' THEN 1
    WHEN readmission_window = '8-14 days (High Risk)' THEN 2
    WHEN readmission_window = '15-30 days (Moderate)' THEN 3
    WHEN readmission_window = '>30 days (Low Risk)' THEN 4
END;
```

**What it does**: Aggregate analysis of readmission timing patterns across all patients

**Typical Output**:
```
| Readmission Window      | Patient Count | Avg Days | Min | Max | % of Total |
|-------------------------|---------------|----------|-----|-----|------------|
| ≤7 days (Critical)      | 145           | 4.5      | 1   | 7   | 14.12%     |
| 8-14 days (High Risk)   | 167           | 11.2     | 8   | 14  | 16.27%     |
| 15-30 days (Moderate)   | 298           | 22.4     | 15  | 30  | 29.02%     |
| >30 days (Low Risk)     | 415           | 95.3     | 31  | 365 | 40.49%     |
```

**Key Insights from Example**:

1. **30.39% readmit within 14 days** (145 + 167 = 312 patients)
   - These are CRITICAL + HIGH RISK
   - Primary intervention opportunity

2. **59.41% readmit within 30 days** (145 + 167 + 298 = 610 patients)
   - Subject to CMS penalties
   - Target for transitional care programs

3. **14.12% readmit within 7 days**
   - Premature discharge indicator
   - Quality of care concern

**Business Impact Calculation**:
```
Assume hospital has 10,000 admissions/year
30.39% × 10,000 = 3,039 rapid readmissions
Average cost per readmission = $15,000
Total unnecessary cost = 3,039 × $15,000 = $45.6M

If interventions prevent 50%:
Savings = $22.8M
```

**Window Function** `SUM(COUNT(*)) OVER()`:
- Calculates total across all groups
- Used for percentage calculation
- No PARTITION BY = single value across entire result

---

### Q37: Diagnosis-Specific Readmission Speed
**File**: `readmission_intervals_results_analysis.sql` | **Lines**: 138-174

```sql
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
WHERE days_gap IS NOT NULL
GROUP BY primary_diagnosis
ORDER BY avg_days_to_readmit ASC;
```

**What it does**: Identifies which diagnoses have fastest readmission cycles

**Statistical Measures**:
- **AVG (mean)**: Average days to readmit
- **MEDIAN**: Middle value (less affected by outliers)
- **MIN**: Fastest readmission
- **MAX**: Slowest readmission

**Why MEDIAN matters**:
- Avg can be skewed by outliers
- Median represents "typical" patient
- Example: Avg = 30 days (one patient waited 200 days), Median = 18 days (more realistic)

**Expected Clinical Patterns**:

```
| Diagnosis      | Count | Avg Days | Median | Min | Max |
|----------------|-------|----------|--------|-----|-----|
| Heart Failure  | 156   | 18.4     | 14.0   | 2   | 180 | ← FASTEST
| Sepsis         | 124   | 21.7     | 17.0   | 1   | 195 |
| MI             | 98    | 25.3     | 22.0   | 3   | 200 |
| Pneumonia      | 67    | 35.2     | 32.0   | 5   | 210 |
| COPD           | 54    | 42.1     | 38.0   | 8   | 225 | ← SLOWEST
```

**Clinical Interpretation**:

**Heart Failure (avg 18.4 days)**:
- **Why so fast?** Fluid reaccumulates quickly if medication non-adherence
- **Intervention**: Daily weight monitoring, telehealth, diuretic adjustment
- **Cost**: Home monitoring program ($500) vs. readmission ($15,000)

**Sepsis (avg 21.7 days)**:
- **Why fast?** Weakened immune system post-infection
- **Intervention**: Extended antibiotic therapy, infection monitoring

**COPD (avg 42.1 days)**:
- **Why slower?** Chronic progressive disease, slower decline
- **Intervention**: Standard pulmonary rehabilitation

**Actionable Insight**: 
Heart Failure patients readmit 2.3× faster than COPD (18.4 vs 42.1 days)
→ Allocate MORE resources to Heart Failure transitional care

**PERCENTILE_CONT** Explanation:
- Continuous percentile (interpolates between values)
- 0.5 = 50th percentile = median
- Alternative: PERCENTILE_DISC (discrete, returns actual value from dataset)

---

### Q38: Frequent Flyer Analysis
**File**: `readmission_intervals_results_analysis.sql` | **Lines**: 226-261

```sql
SELECT 
    patient_id,
    COUNT(*) as total_readmissions,
    ROUND(AVG(days_gap), 1) as avg_days_between_visits,
    MIN(days_gap) as fastest_readmit,
    MAX(days_gap) as slowest_readmit,
    ROUND(100.0 * SUM(CASE WHEN days_gap <= 30 THEN 1 ELSE 0 END) / COUNT(*), 0) as pct_rapid_readmit
FROM (
    SELECT 
        patient_id,
        admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
    FROM hospital_readmission
) gaps
WHERE days_gap IS NOT NULL
GROUP BY patient_id
HAVING COUNT(*) >= 3
ORDER BY total_readmissions DESC
LIMIT 10;
```

**What it does**: Identifies "revolving door" patients with multiple readmissions

**HAVING COUNT(*) >= 3**:
- Filters to patients with 3+ readmissions
- These are "frequent flyers" or "super-utilizers"

**Metrics Explained**:

1. **total_readmissions**: How many times patient returned
2. **avg_days_between_visits**: Average interval between discharges and readmissions
3. **fastest_readmit**: Shortest gap (worst episode)
4. **slowest_readmit**: Longest gap (best episode)
5. **pct_rapid_readmit**: % of readmissions within 30 days

**Example Output**:
```
| patient_id | total_readmissions | avg_days_between | fastest | slowest | pct_rapid |
|------------|--------------------|--------------------|---------|---------|-----------|
| PAT00542   | 7                  | 22.3              | 5       | 145     | 57%       |
| PAT01234   | 6                  | 28.1              | 8       | 98      | 50%       |
| PAT02089   | 5                  | 31.4              | 12      | 120     | 40%       |
```

**High-Risk Profile (PAT00542)**:
- 7 readmissions in timeframe
- Avg 22.3 days between visits (very short cycle)
- Fastest readmission was 5 days (critical!)
- 57% of readmissions within 30 days (very high)

**Why These Patients Matter**:

**Cost Concentration**:
- 5% of patients = 50% of costs (Pareto Principle)
- PAT00542 with 7 readmissions × $15,000 = $105,000 in one year

**Quality Indicator**:
- Multiple rapid readmissions = care delivery failure
- Not addressing root causes

**Patient Experience**:
- Revolving door = poor quality of life
- Indicates unmet needs

**Root Causes of Frequent Readmissions**:
1. **Clinical**: Complex multi-morbidity, non-adherence
2. **Social**: Homelessness, food insecurity, lack of caregiver
3. **Mental Health**: Depression, substance abuse
4. **System**: Fragmented care, poor care coordination

**Intervention: Intensive Case Management**:
- Assign dedicated case manager
- Weekly home visits
- Medication delivery
- Transportation assistance
- Social work for housing/food
- Mental health support
- 24/7 hotline

**ROI**: 
- Program cost: $10,000/patient/year
- Savings: Prevent 3 readmissions × $15,000 = $45,000
- Net savings: $35,000 per patient

**Targeting Strategy**:
```sql
-- Identify patients for intensive case management
WHERE total_readmissions >= 3
  AND (avg_days_between_visits < 30 OR pct_rapid_readmit > 50%)
```

---

### Q39: High-Risk Readmission Count
**File**: `readmission_intervals_results_analysis.sql` | **Lines**: 112-125

```sql
SELECT 
    COUNT(*) as total_readmissions,
    SUM(CASE WHEN days_gap <= 30 THEN 1 ELSE 0 END) as high_risk_readmissions,
    ROUND(100.0 * SUM(CASE WHEN days_gap <= 30 THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_high_risk
FROM (
    SELECT 
        patient_id,
        admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) 
            as days_gap
    FROM hospital_readmission
) gaps
WHERE days_gap IS NOT NULL;
```

**What it does**: Calculates proportion of readmissions occurring within CMS penalty window (30 days)

**Key Metrics**:

1. **total_readmissions**: All readmissions (any timeframe)
2. **high_risk_readmissions**: Only those ≤30 days
3. **pct_high_risk**: Percentage of rapid readmissions

**Example Output**:
```
| total_readmissions | high_risk_readmissions | pct_high_risk |
|--------------------|------------------------|---------------|
| 1,020              | 325                    | 31.86%        |
```

**Interpretation**:
- Hospital has 1,020 total readmissions
- 325 (31.86%) occur within 30 days
- Subject to CMS penalties

**Industry Benchmarks**:
- **Excellent**: <20% rapid readmissions
- **Average**: 20-30%
- **Poor**: >30%

**Financial Impact**:
```
Hospital with 10,000 annual admissions
31.86% rapid readmission rate
10,000 × 0.32 = 3,200 rapid readmissions

CMS penalty calculation:
3,200 readmissions × $15,000 avg cost = $48M
If >national avg → up to 3% penalty on ALL Medicare payments
```

**Quality Improvement Target**:
```
Current: 31.86%
Industry best practice: 20%
Gap: 11.86% = preventable readmissions

If reduce to 20%:
Prevented readmissions = 11.86% of 10,000 = 1,186
Savings = 1,186 × $15,000 = $17.8M annually
```

---

## Financial Analytics Queries

### Q40: Revenue per Diagnosis
**File**: `01_table_creation_and_data.sql` | **Lines**: 425-433

```sql
SELECT 
    primary_diagnosis,
    COUNT(*) as case_count,
    SUM(total_bill_amount) as total_revenue,
    ROUND(AVG(total_bill_amount), 0) as avg_revenue_per_case,
    ROUND(SUM(total_bill_amount) / SUM(SUM(total_bill_amount)) OVER() * 100, 2) as pct_of_total_revenue
FROM hospital_readmission
WHERE total_bill_amount IS NOT NULL
GROUP BY primary_diagnosis
ORDER BY total_revenue DESC;
```

**What it does**: Identifies most profitable diagnoses for strategic service line focus

**Metrics Explained**:

1. **case_count**: Volume (number of patients)
2. **total_revenue**: Aggregate revenue from this diagnosis
3. **avg_revenue_per_case**: Revenue per patient
4. **pct_of_total_revenue**: Revenue concentration

**Window Function** `SUM(SUM(...)) OVER()`:
- Inner SUM: Group-level aggregation
- Outer SUM ... OVER: Grand total across all groups
- Used for percentage calculation

**Example Output**:
```
| Diagnosis      | Cases | Total Revenue | Avg/Case | % of Total |
|----------------|-------|---------------|----------|------------|
| MI             | 500   | $25,000,000   | $50,000  | 22.5%      |
| Heart Failure  | 1000  | $30,000,000   | $30,000  | 27.0%      |
| Pneumonia      | 800   | $18,000,000   | $22,500  | 16.2%      |
| Diabetes       | 1200  | $20,000,000   | $16,667  | 18.0%      |
```

**Strategic Insights**:

**High Volume + High Revenue** (Heart Failure):
- 1000 cases, $30M revenue
- Core service line
- **Strategy**: Maintain excellence, build reputation

**Low Volume + High Avg Revenue** (MI):
- 500 cases but $50K average
- Cardiac procedures (cath lab, stents)
- **Strategy**: Grow volume through marketing, physician recruitment

**High Volume + Low Revenue** (Diabetes):
- 1200 cases but only $16,667 average
- Routine medical management
- **Strategy**: Focus on efficiency, reduce LOS

**Revenue Concentration Risk**:
- If top 3 diagnoses = 60% of revenue
- Risk if payer changes reimbursement or market shifts
- **Mitigation**: Diversify service lines

**Pareto Analysis**:
```sql
-- Identify diagnoses contributing to 80% of revenue
SELECT *, 
       SUM(pct_of_total_revenue) OVER(ORDER BY total_revenue DESC) as cumulative_pct
FROM (above query)
WHERE cumulative_pct <= 80;
```

---

### Q41: Bad Debt Risk (Self-Pay High Bills)
**File**: `01_table_creation_and_data.sql` | **Lines**: 1239-1249

```sql
SELECT 
    patient_id,
    total_bill_amount,
    household_income
FROM hospital_readmission
WHERE insurance_type = 'Self-Pay'
  AND total_bill_amount > (household_income * 0.20)
ORDER BY total_bill_amount DESC;
```

**What it does**: Identifies self-pay patients with bills exceeding 20% of annual income

**Financial Risk Logic**:

**20% of Annual Income Threshold**:
- Based on healthcare affordability research
- Bills >20% of income rarely paid in full
- Example: $60,000 income → $12,000 threshold

**Self-Pay = Uninsured**:
- No insurance company to pay
- Patient responsible for 100% of bill
- High collection risk

**Example Scenarios**:

**High Risk** (Bill > 20% of Income):
```
Patient: PAT00234
Income: $30,000/year
Bill: $15,000
Ratio: 50% of annual income
Likelihood of payment: <10%
```

**Moderate Risk** (Bill = 10-20% of Income):
```
Patient: PAT01892
Income: $50,000/year
Bill: $8,000
Ratio: 16% of annual income
Likelihood of payment: 40-60% (payment plan possible)
```

**Example Output**:
```
| patient_id | total_bill | household_income | % of Income |
|------------|------------|------------------|-------------|
| PAT02341   | $25,000    | $35,000          | 71.4%       |
| PAT01892   | $18,000    | $28,000          | 64.3%       |
| PAT03421   | $15,000    | $30,000          | 50.0%       |
```

**Financial Impact**:
```
100 patients with avg bad debt of $15,000 each
= $1.5M in uncollectible revenue

Hospital must either:
1. Write off as bad debt (reduces net revenue)
2. Send to collections (expensive, poor recovery rate)
3. Offer charity care (tax benefit but still a loss)
```

**Interventions Before Discharge**:

1. **Financial Counseling**:
   - Screen for charity care eligibility
   - Medicaid enrollment assistance
   - Payment plan options

2. **Charity Care Screening**:
   - Income <200% federal poverty level may qualify
   - Reduces bad debt write-offs
   - Tax benefit for hospital

3. **Payment Plans**:
   - $15,000 bill → $300/month for 50 months
   - Increases collection rate from 10% to 60%

4. **Social Work Referral**:
   - Connect to community resources
   - Address underlying financial instability

**Predictive Query**:
```sql
-- Estimate total bad debt exposure
SELECT 
    COUNT(*) as at_risk_patients,
    SUM(total_bill_amount) as total_exposure,
    SUM(total_bill_amount) * 0.70 as estimated_bad_debt -- Assume 70% uncollectible
FROM hospital_readmission
WHERE insurance_type = 'Self-Pay'
  AND total_bill_amount > (household_income * 0.20);
```

---

### Q42: Revenue Efficiency (Revenue per Day)
**File**: `01_table_creation_and_data.sql` | **Lines**: 1225-1237

```sql
SELECT 
    primary_diagnosis,
    ROUND(AVG(total_bill_amount), 0) as revenue,
    ROUND(AVG(length_of_stay), 1) as days,
    ROUND(AVG(total_bill_amount) / NULLIF(AVG(length_of_stay), 0), 0) as rev_per_day
FROM hospital_readmission
GROUP BY primary_diagnosis
ORDER BY rev_per_day DESC;
```

**What it does**: Measures operational efficiency by diagnosis

**Why Revenue/Day Matters**:

**Hospital Capacity is Fixed**:
- 500 beds in hospital
- Each bed occupied = opportunity cost
- High revenue/day = efficient use of resources

**Efficiency Metric**:
```
Revenue per Day = Total Revenue ÷ Length of Stay

High Rev/Day = Short stay with high charges (procedures)
Low Rev/Day = Long stay with low charges (medical management)
```

**NULLIF() Explanation**:
- `NULLIF(AVG(length_of_stay), 0)` returns NULL if LOS = 0
- Prevents division by zero error
- Result: NULL instead of error

**Example Output**:
```
| Diagnosis          | Revenue | Days | Rev/Day  | Efficiency |
|--------------------|---------|------|----------|------------|
| Cardiac Cath       | $45,000 | 2.1  | $21,429  | EXCELLENT  |
| MI (with PCI)      | $60,000 | 4.5  | $13,333  | GOOD       |
| Heart Failure      | $30,000 | 5.8  | $5,172   | MODERATE   |
| Pneumonia          | $22,000 | 6.2  | $3,548   | POOR       |
| Rehab              | $25,000 | 14.0 | $1,786   | INEFFICIENT|
```

**Strategic Implications**:

**High Efficiency (Cardiac Cath: $21,429/day)**:
- Short procedure (2 days)
- High reimbursement
- **Strategy**: Maximize volume (add cath lab capacity)
- **ROI**: High capital investment but strong returns

**Low Efficiency (Rehab: $1,786/day)**:
- Long stay (14 days)
- Low daily reimbursement
- **Options**: 
  1. Outsource to SNF (free up acute beds)
  2. Create dedicated rehab unit (different payment model)
  3. Reduce LOS through aggressive therapy

**Profitability Calculation**:
```
Hospital has 500 beds

Scenario A: Fill with Cardiac Cath patients
500 beds × $21,429/day × 365 days = $3.9B annual revenue

Scenario B: Fill with Pneumonia patients
500 beds × $3,548/day × 365 days = $647M annual revenue

Difference: $3.25B
```

**Reality**: Must balance high and low efficiency cases

**Optimization Strategy**:
1. Identify beds dedicated to high-efficiency procedures
2. Move low-efficiency cases to lower-cost units
3. Reduce LOS for medical cases through clinical pathways

---

### Q43: Frequent Flyer Cost Burden (Pareto)
**File**: `01_table_creation_and_data.sql` | **Lines**: 1252-1267

```sql
WITH PatientSpend AS (
    SELECT patient_id, SUM(total_bill_amount) as total_spend
    FROM hospital_readmission
    GROUP BY patient_id
)
SELECT 
    SUM(total_spend) FILTER (WHERE ntile_rank = 1) as top_1_percent_cost,
    SUM(total_spend) as total_hospital_revenue
FROM (
    SELECT total_spend, NTILE(100) OVER(ORDER BY total_spend DESC) as ntile_rank
    FROM PatientSpend
) Sub;
```

**What it does**: Tests Pareto Principle (80/20 rule) in healthcare spending

**Query Structure**:

1. **CTE (PatientSpend)**: Calculates total spending per patient across all admissions
2. **NTILE(100)**: Divides patients into 100 equal groups (percentiles)
3. **FILTER (WHERE ntile_rank = 1)**: Selects top 1% (highest spenders)

**Pareto Principle in Healthcare**:
- **Classic**: 80% of effects from 20% of causes
- **Healthcare**: 80% of costs from 20% of patients (or even 5%)

**Example Output**:
```
| top_1_percent_cost | total_hospital_revenue | % of Total |
|--------------------|------------------------|------------|
| $22,500,000        | $125,000,000           | 18.0%      |
```

**Interpretation**:
- Top 1% of patients (50 out of 5,000) consumed $22.5M
- Total revenue = $125M
- Top 1% = 18% of total costs

**Business Insight**:
```
If we can reduce costs for these 50 patients by 30%:
Savings = $22.5M × 0.30 = $6.75M annually

Intensive case management program for 50 patients:
Cost = 50 × $10,000 = $500,000
Net savings = $6.75M - $500K = $6.25M

ROI = 1,250% (12.5:1 return)
```

**Targeting Strategy**:
```sql
-- Identify top 1% of spenders for intervention
WITH PatientSpend AS (
    SELECT patient_id, SUM(total_bill_amount) as total_spend
    FROM hospital_readmission
    GROUP BY patient_id
)
SELECT patient_id, total_spend
FROM (
    SELECT *, NTILE(100) OVER(ORDER BY total_spend DESC) as percentile
    FROM PatientSpend
)
WHERE percentile = 1  -- Top 1%
ORDER BY total_spend DESC;
```

**Root Causes of High Spending** (in top 1%):
1. Complex chronic disease (multiple comorbidities)
2. Frequent readmissions (revolving door)
3. ICU utilization
4. Lack of care coordination
5. Social determinants (homelessness, substance abuse)

**Intervention Programs**:
- **Intensive Case Management**: Dedicated nurse, social worker
- **Care Coordination**: Primary care + specialists aligned
- **Home Monitoring**: Telehealth, remote vital signs
- **Social Support**: Housing, food, transportation
- **Mental Health**: Depression, substance abuse treatment

---

### Q44: Insurance Profitability Analysis
**File**: `01_table_creation_and_data.sql` | **Lines**: 435-445

```sql
SELECT 
    insurance_type,
    COUNT(*) as patients,
    ROUND(AVG(total_bill_amount), 0) as avg_bill,
    ROUND(AVG(out_of_pocket_ratio), 3) as avg_oop_ratio,
    ROUND(AVG(total_bill_amount * out_of_pocket_ratio), 0) as avg_patient_payment,
    ROUND(AVG(total_bill_amount * (1 - out_of_pocket_ratio)), 0) as avg_insurance_payment
FROM hospital_readmission
WHERE total_bill_amount IS NOT NULL
GROUP BY insurance_type
ORDER BY avg_insurance_payment DESC;
```

**What it does**: Analyzes revenue composition by payer type

**Calculation Breakdown**:

**out_of_pocket_ratio**:
- Proportion patient pays directly
- Example: 0.20 = patient pays 20%, insurance pays 80%

**avg_patient_payment**:
- `total_bill_amount × out_of_pocket_ratio`
- $30,000 × 0.20 = $6,000 patient responsibility

**avg_insurance_payment**:
- `total_bill_amount × (1 - out_of_pocket_ratio)`
- $30,000 × 0.80 = $24,000 insurance reimbursement

**Example Output**:
```
| Insurance | Patients | Avg Bill | OOP Ratio | Patient Pays | Insurance Pays | Collection Risk |
|-----------|----------|----------|-----------|--------------|----------------|-----------------|
| Private   | 1,500    | $32,000  | 0.180     | $5,760       | $26,240        | Low             |
| Medicare  | 1,750    | $28,000  | 0.200     | $5,600       | $22,400        | Very Low        |
| Medicaid  | 1,250    | $26,000  | 0.050     | $1,300       | $24,700        | Very Low        |
| Self-Pay  | 500      | $25,000  | 1.000     | $25,000      | $0             | Very High       |
```

**Payer Mix Strategy**:

**Private Insurance** (Most Profitable):
- Highest reimbursement ($26,240)
- Reliable payment
- **Strategy**: Market to employers, accept PPO/HMO contracts

**Medicare** (Moderate):
- Moderate reimbursement ($22,400)
- Guaranteed payment (government)
- High volume (aging population)
- **Strategy**: Optimize efficiency, focus on quality metrics

**Medicaid** (Lower Reimbursement):
- Lower payment ($24,700 but lower bill amounts)
- Guaranteed payment
- Higher social needs
- **Strategy**: Participate if mission-driven or required, manage costs

**Self-Pay** (Highest Risk):
- No insurance payment ($0)
- Patient owes 100% ($25,000)
- 40-60% bad debt rate
- **Strategy**: Financial counseling, charity care screening

**Portfolio Strategy**:
```
Ideal payer mix for profitability:
- 40% Private insurance
- 30% Medicare
- 20% Medicaid
- 10% Self-pay (with aggressive charity care screening)
```

**Financial Planning**:
```
Current revenue: $125M
If shift 10% volume from Self-Pay to Private:
10% of 500 = 50 patients
Lost Self-Pay revenue: 50 × $25,000 × 0.30 (collection rate) = $375,000
Gained Private revenue: 50 × $32,000 = $1,600,000
Net gain: $1,225,000
```

---

## Advanced Analytics Queries

### Q45: Executive Dashboard (Multi-CTE)
**File**: `01_table_creation_and_data.sql` | **Lines**: 1123-1137

```sql
WITH 
    Financials AS (SELECT SUM(total_bill_amount) as rev FROM hospital_readmission),
    Volume AS (SELECT COUNT(*) as vol FROM hospital_readmission),
    Rates AS (SELECT AVG(readmitted_30_days) as rate FROM hospital_readmission),
    TopDiag AS (
        SELECT primary_diagnosis FROM hospital_readmission 
        GROUP BY 1 ORDER BY COUNT(*) DESC LIMIT 1
    )
SELECT 
    rev as "Total Revenue",
    vol as "Total Patients",
    ROUND(rate * 100, 2) as "Readmission %",
    primary_diagnosis as "Top Driver"
FROM Financials, Volume, Rates, TopDiag;
```

**What it does**: Creates single-row executive summary combining unrelated metrics

**CTE Architecture**:

1. **Financials CTE**: Calculates total revenue
2. **Volume CTE**: Counts total admissions
3. **Rates CTE**: Computes readmission rate
4. **TopDiag CTE**: Identifies most common diagnosis

**Cartesian Join Strategy**:
- `FROM Financials, Volume, Rates, TopDiag`
- Each CTE returns exactly 1 row
- Cartesian join of 1×1×1×1 = 1 row (safe!)
- Combines all metrics into single dashboard row

**Why NOT use JOIN?**:
- CTEs are unrelated (different aggregation levels)
- No common key to join on
- Cartesian join is intentional and correct here

**Example Output**:
```
| Total Revenue | Total Patients | Readmission % | Top Driver    |
|---------------|----------------|---------------|---------------|
| $125,000,000  | 5,000          | 19.85%        | Heart Failure |
```

**Use Cases**:
1. **Daily Executive Email**: Single-line summary
2. **Board Report**: Hospital scorecard
3. **Quality Dashboard**: Key performance indicators (KPIs)

**Automation**:
```sql
-- Schedule this query to run daily at 6 AM
-- Email results to C-suite

CREATE OR REPLACE FUNCTION send_daily_dashboard()
RETURNS void AS $$
BEGIN
    -- Execute query
    -- Format as HTML table
    -- Send email via pg_notify or external service
END;
$$ LANGUAGE plpgsql;
```

**Expandable Version** (Add More Metrics):
```sql
WITH 
    Financials AS (...),
    Volume AS (...),
    Rates AS (...),
    TopDiag AS (...),
    ICU_Metrics AS (SELECT AVG(icu_utilization_ratio) as icu_rate FROM hospital_readmission),
    LOS_Stats AS (SELECT AVG(discharge_date - admission_date) as avg_los FROM hospital_readmission)
SELECT 
    rev as "Total Revenue",
    vol as "Total Patients",
    ROUND(rate * 100, 2) as "Readmission %",
    primary_diagnosis as "Top Driver",
    ROUND(icu_rate * 100, 2) as "ICU Utilization %",
    ROUND(avg_los, 1) as "Avg LOS"
FROM Financials, Volume, Rates, TopDiag, ICU_Metrics, LOS_Stats;
```

---

### Q46: JSON Patient Summary
**File**: `01_table_creation_and_data.sql` | **Lines**: 1097-1106

```sql
SELECT 
    patient_id,
    json_build_object(
        'total_spent', SUM(total_bill_amount),
        'visits', COUNT(*)
    ) as patient_summary
FROM hospital_readmission
GROUP BY patient_id;
```

**What it does**: Creates structured JSON output for API integration or export

**JSON_BUILD_OBJECT Function**:
- Builds JSON object from key-value pairs
- Syntax: `json_build_object('key1', value1, 'key2', value2, ...)`
- Result: `{"key1": value1, "key2": value2}`

**Example Output**:
```json
{
  "patient_id": "PAT00001",
  "patient_summary": {
    "total_spent": 45000.00,
    "visits": 3
  }
}
{
  "patient_id": "PAT00002",
  "patient_summary": {
    "total_spent": 28000.00,
    "visits": 1
  }
}
```

**Use Cases**:

1. **REST API Response**:
```javascript
// Node.js Express endpoint
app.get('/api/patients/:id/summary', async (req, res) => {
  const result = await db.query(
    'SELECT patient_id, json_build_object(...) FROM ...'
  );
  res.json(result.rows[0].patient_summary);
});
```

2. **Data Export**:
```bash
psql -d hospital_analytics -c "SELECT ..." > patient_summaries.json
```

3. **BI Tool Integration**:
- Tableau can parse JSON fields
- Power BI imports JSON
- Python pandas reads JSON

**Advanced JSON Functions**:

**JSON_AGG** (Array of Objects):
```sql
SELECT 
    insurance_type,
    json_agg(json_build_object(
        'patient_id', patient_id,
        'total_bill', total_bill_amount
    )) as patients
FROM hospital_readmission
GROUP BY insurance_type;
```

Output:
```json
{
  "insurance_type": "Medicare",
  "patients": [
    {"patient_id": "PAT00001", "total_bill": 30000},
    {"patient_id": "PAT00002", "total_bill": 25000},
    ...
  ]
}
```

**Nested JSON**:
```sql
SELECT 
    patient_id,
    json_build_object(
        'demographics', json_build_object(
            'age', age,
            'gender', gender
        ),
        'financial', json_build_object(
            'total_spent', SUM(total_bill_amount),
            'avg_visit_cost', AVG(total_bill_amount)
        ),
        'clinical', json_build_object(
            'readmission_rate', AVG(readmitted_30_days),
            'avg_comorbidity', AVG(comorbidity_score)
        )
    ) as complete_profile
FROM hospital_readmission
GROUP BY patient_id, age, gender;
```

---

## Complete Query Count

**Total Queries Documented**: 46 comprehensive queries

### Breakdown by Category:
- **Data Cleaning**: 8 queries
- **Basic Aggregation**: 12 queries
- **Window Functions**: 7 queries
- **Clinical Risk Analysis**: 7 queries
- **Financial Analytics**: 5 queries
- **Readmission Interval Analysis**: 6 queries
- **Advanced Analytics**: 2 queries

---

## Query Complexity Levels

### Beginner (Simple SELECT, WHERE, GROUP BY):
- Q1, Q2, Q3, Q4, Q5, Q7, Q9, Q10, Q11

### Intermediate (Aggregations, CASE, Joins):
- Q6, Q8, Q12, Q13, Q14, Q15, Q16, Q17, Q18, Q19, Q20

### Advanced (Window Functions, CTEs):
- Q21, Q22, Q23, Q24, Q25, Q26, Q27, Q28, Q29, Q30, Q31, Q32

### Expert (Complex CTEs, Multiple Window Functions):
- Q33, Q34, Q35, Q36, Q37, Q38, Q39, Q40, Q41, Q42, Q43, Q44, Q45, Q46

---

## SQL Techniques Demonstrated

✅ Basic Queries (SELECT, WHERE, ORDER BY)
✅ Aggregation Functions (COUNT, SUM, AVG, MIN, MAX)
✅ GROUP BY and HAVING
✅ CASE Statements (Conditional Logic)
✅ Date Arithmetic
✅ COALESCE (NULL Handling)
✅ String Functions (TRIM, LOWER, UPPER, INITCAP)
✅ Window Functions (ROW_NUMBER, RANK, DENSE_RANK, NTILE)
✅ LAG/LEAD (Accessing Previous/Next Rows)
✅ Running Totals (Cumulative Aggregation)
✅ Moving Averages
✅ CUME_DIST (Cumulative Distribution)
✅ PERCENTILE_CONT (Statistical Percentiles)
✅ Common Table Expressions (CTEs)
✅ Multiple CTEs with Cartesian Join
✅ Subqueries
✅ JSON Functions (json_build_object, json_agg)
✅ Window Frames (ROWS BETWEEN, UNBOUNDED PRECEDING)
✅ FILTER Clause (PostgreSQL-specific aggregation)
✅ Date Functions (EXTRACT, DATE_TRUNC, TO_CHAR)

---

## Healthcare Domain Knowledge

This query reference demonstrates:

✅ Clinical Risk Stratification
✅ Charlson Comorbidity Index
✅ LACE Score Methodology
✅ CMS Readmission Penalties
✅ Social Determinants of Health (SDOH)
✅ Payer Mix Analysis
✅ DRG Payment System Understanding
✅ Care Coordination Strategies
✅ Pareto Principle in Healthcare
✅ Financial Counseling Thresholds
✅ ICU Utilization Metrics
✅ Medication Adherence Impact
✅ Length of Stay Optimization
✅ Revenue Cycle Management
✅ Bad Debt Risk Assessment

---

**Every query in this reference includes**:
1. SQL code with line numbers
2. Plain English explanation ("What it does")
3. Technical breakdown (functions, syntax, logic)
4. Business/clinical interpretation
5. Example output with realistic values
6. Use cases and applications
7. Strategic insights and actions

**No query is left unexplained** ✅
