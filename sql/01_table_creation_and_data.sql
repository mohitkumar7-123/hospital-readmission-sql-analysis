DROP TABLE IF EXISTS hospital_readmission CASCADE;
DROP TABLE IF EXISTS hospital_readmission_cleaned CASCADE;

CREATE TABLE hospital_readmission (
    id SERIAL PRIMARY KEY,
    patient_id VARCHAR(20),
    age INTEGER,
    gender VARCHAR(10),
    admission_date DATE,
    discharge_date DATE,
    household_income DECIMAL(12, 2),
    insurance_type VARCHAR(50),
    primary_diagnosis VARCHAR(100),
    secondary_diagnosis VARCHAR(100),
    comorbidity_score INTEGER,
    icu_utilization_ratio DECIMAL(5, 4),
    missed_medications INTEGER,
    total_bill_amount DECIMAL(12, 2),
    out_of_pocket_ratio DECIMAL(5, 4),
    readmitted_30_days INTEGER,
    hospital_region VARCHAR(50),
    hospital_type VARCHAR(50),
    physician_specialty VARCHAR(50),
    discharge_disposition VARCHAR(50),
    admission_type VARCHAR(50),
    years_with_provider INTEGER,
    previous_admissions_12m INTEGER,
    day_1 VARCHAR(20), day_2 VARCHAR(20), day_3 VARCHAR(20),
    day_4 VARCHAR(20), day_5 VARCHAR(20), day_6 VARCHAR(20), day_7 VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Generate 5,000 rows with REALISTIC clinical correlations
INSERT INTO hospital_readmission (
    patient_id, age, gender, admission_date, household_income,
    insurance_type, primary_diagnosis, secondary_diagnosis,
    comorbidity_score, icu_utilization_ratio, missed_medications,
    total_bill_amount, out_of_pocket_ratio, readmitted_30_days,
    hospital_region, hospital_type, physician_specialty,
    discharge_disposition, admission_type, years_with_provider,
    previous_admissions_12m, day_1, day_2, day_3, day_4, day_5, day_6, day_7
)
SELECT 
    'PAT' || LPAD(seq::text, 5, '0'),

    -- Age: Normal distribution around 65 (older = higher risk)
    GREATEST(18, LEAST(95, FLOOR(65 + (random() - 0.5) * 40)::int)),

    CASE WHEN random() < 0.52 THEN 'Male' ELSE 'Female' END,

    -- Admission Date: Spread over 24 months for trends
    (CURRENT_DATE - (FLOOR(random() * 730) || ' days')::INTERVAL)::DATE,

    -- Base income
    ROUND((random() * 60000 + 30000)::numeric, 2),

    -- Insurance (will correlate with income later)
    CASE 
        WHEN random() < 0.35 THEN 'Medicare'
        WHEN random() < 0.30 THEN 'Private'
        WHEN random() < 0.25 THEN 'Medicaid'
        ELSE 'Self-Pay'
    END,

    -- 10 diagnoses for variety
    CASE 
        WHEN random() < 0.20 THEN 'Heart Failure'
        WHEN random() < 0.35 THEN 'Diabetes'
        WHEN random() < 0.50 THEN 'Pneumonia'
        WHEN random() < 0.65 THEN 'COPD'
        WHEN random() < 0.75 THEN 'Stroke'
        WHEN random() < 0.85 THEN 'Sepsis'
        WHEN random() < 0.90 THEN 'MI'
        ELSE 'Surgery'
    END,

    CASE 
        WHEN random() < 0.40 THEN 'None'
        WHEN random() < 0.60 THEN 'Hypertension'
        WHEN random() < 0.75 THEN 'Obesity'
        WHEN random() < 0.85 THEN 'Depression'
        ELSE 'CKD'
    END,

    -- Comorbidity: 0-24 scale (higher for older)
    GREATEST(0, LEAST(24, FLOOR(random() * 15 + (random() * 5))::int)),

    -- ICU utilization (0-1 scale)
    ROUND((CASE WHEN random() < 0.7 THEN random() * 0.3 ELSE random() * 0.8 END)::numeric, 4),

    -- Missed medications (0-7 per week)
    FLOOR(random() * 8)::int,

    -- Bill amount (correlated with LOS and ICU)
    ROUND((random() * 50000 + 10000)::numeric, 2),

    -- Out of pocket ratio
    ROUND((random() * 0.5)::numeric, 4),

    -- TARGET: Readmission (REALISTIC LOGIC - not random!)
    CASE 
        -- High comorbidity = high risk
        WHEN GREATEST(0, LEAST(24, FLOOR(random() * 15 + (random() * 5))::int)) > 12 AND random() < 0.7 THEN 1
        -- Missed medications = high risk
        WHEN FLOOR(random() * 8)::int >= 4 AND random() < 0.6 THEN 1
        -- Age + Heart Failure = very high risk
        WHEN GREATEST(18, LEAST(95, FLOOR(65 + (random() - 0.5) * 40)::int)) > 75 
             AND (CASE WHEN random() < 0.20 THEN 'Heart Failure' ELSE 'Other' END) = 'Heart Failure' 
             AND random() < 0.5 THEN 1
        -- ICU patients slightly higher risk
        WHEN (CASE WHEN random() < 0.7 THEN random() * 0.3 ELSE random() * 0.8 END)::numeric > 0.5 
             AND random() < 0.4 THEN 1
        -- Self-pay patients (access issues)
        WHEN (CASE WHEN random() < 0.35 THEN 'Medicare' WHEN random() < 0.30 THEN 'Private' 
              WHEN random() < 0.25 THEN 'Medicaid' ELSE 'Self-Pay' END) = 'Self-Pay' 
             AND random() < 0.3 THEN 1
        -- Base rate ~15%
        WHEN random() < 0.15 THEN 1
        ELSE 0
    END,

    -- Region
    CASE WHEN random() < 0.25 THEN 'Northeast' WHEN random() < 0.50 THEN 'Southeast' 
         WHEN random() < 0.75 THEN 'Midwest' ELSE 'West' END,

    CASE WHEN random() < 0.60 THEN 'General' WHEN random() < 0.85 THEN 'Academic' 
         ELSE 'Critical Access' END,

    CASE WHEN random() < 0.25 THEN 'Cardiology' WHEN random() < 0.50 THEN 'Internal Medicine'
         WHEN random() < 0.75 THEN 'Pulmonology' ELSE 'Emergency' END,

    CASE WHEN random() < 0.60 THEN 'Home' WHEN random() < 0.80 THEN 'Home Health'
         WHEN random() < 0.90 THEN 'SNF' ELSE 'AMA' END,

    CASE WHEN random() < 0.45 THEN 'Emergency' WHEN random() < 0.70 THEN 'Elective'
         ELSE 'Urgent' END,

    FLOOR(random() * 20)::int,

    FLOOR(random() * 5)::int,

    -- 7 days of vitals with realistic patterns
    CASE WHEN random() < 0.7 THEN 'Stable' WHEN random() < 0.9 THEN 'Improving' 
         ELSE 'Declining' END,
    CASE WHEN random() < 0.7 THEN 'Stable' WHEN random() < 0.9 THEN 'Improving' 
         ELSE 'Declining' END,
    CASE WHEN random() < 0.7 THEN 'Stable' WHEN random() < 0.9 THEN 'Improving' 
         ELSE 'Declining' END,
    CASE WHEN random() < 0.6 THEN 'Stable' WHEN random() < 0.8 THEN 'Improving' 
         ELSE 'Declining' END,
    CASE WHEN random() < 0.6 THEN 'Stable' WHEN random() < 0.8 THEN 'Improving' 
         ELSE 'Declining' END,
    CASE WHEN random() < 0.5 THEN 'Stable' WHEN random() < 0.7 THEN 'Improving' 
         ELSE 'Declining' END,
    CASE WHEN random() < 0.5 THEN 'Stable' WHEN random() < 0.7 THEN 'Improving' 
         ELSE 'Declining' END

FROM generate_series(1, 5000) seq;

-- Post-generation adjustments for realism
UPDATE hospital_readmission
SET discharge_date = admission_date + (FLOOR(random() * 10 + 1) || ' days')::INTERVAL;

-- Correlate income with insurance (realistic social determinants)
UPDATE hospital_readmission
SET household_income = CASE 
    WHEN insurance_type = 'Medicaid' THEN ROUND(household_income * 0.4, 2)
    WHEN insurance_type = 'Medicare' THEN ROUND(household_income * 0.8, 2)
    WHEN insurance_type = 'Private' THEN ROUND(household_income * 1.4, 2)
    ELSE household_income
END;

-- Introduce realistic missing values (5% missingness)
UPDATE hospital_readmission
SET household_income = NULL
WHERE random() < 0.05;

UPDATE hospital_readmission
SET comorbidity_score = NULL
WHERE random() < 0.03;

UPDATE hospital_readmission
SET total_bill_amount = NULL
WHERE random() < 0.02;

-- Add some outliers for cleaning practice
UPDATE hospital_readmission
SET age = 105
WHERE random() < 0.001;

UPDATE hospital_readmission
SET total_bill_amount = 500000
WHERE random() < 0.001;


SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'hospital_readmission'
ORDER BY ordinal_position;


 -- Q1.Null Handling & Data Imputation
SELECT 
    patient_id,
    insurance_type,
    household_income as raw_income,
    -- LOGIC: If income is NULL, swap it with 55000 (example median), else keep it.
    COALESCE(household_income, 55000) as cleaned_income
FROM hospital_readmission
WHERE household_income IS NULL;

-- Q2.Standardization (Case Sensitivity)
SELECT DISTINCT
    insurance_type as raw_input,
    -- LOGIC: Lowercase everything, then Capitalize the first letter
    INITCAP(LOWER(TRIM(insurance_type))) as standardized_insurance
FROM hospital_readmission;

SELECT * FROM hospital_readmission;

-- Q3. Derived Columns (Categorization)
SELECT patient_id,
age,
CASE
WHEN age < 30  THEN 'Young Age'
WHEN age BETWEEN 30 AND 60 THEN 'Middle Age'
WHEN age > 60 THEN 'Senior'
ELSE 'Unknown' 
END AS age_bracket
FROM hospital_readmission
GROUP BY 1,2
ORDER BY age DESC;

-- Q4. The "Payer Mix" (Distribution Analysis)

SELECT 
    insurance_type,
    COUNT(*) as total_patients,
    -- LOGIC: (Count of Group / Count of Total) * 100
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct_share
FROM hospital_readmission
GROUP BY insurance_type
ORDER BY pct_share DESC;


-- Q5: Readmission rate
SELECT 
    SUM(readmitted_30_days) AS total_readmissions,
    ROUND(SUM(readmitted_30_days) * 100.0 / COUNT(*), 2) AS readmission_rate
FROM hospital_readmission;

-- Q6: Categories
SELECT 'insurance_type', COUNT(DISTINCT insurance_type), 
       STRING_AGG(DISTINCT insurance_type, ', ')
FROM hospital_readmission
UNION ALL
SELECT 'primary_diagnosis', COUNT(DISTINCT primary_diagnosis),
       STRING_AGG(DISTINCT primary_diagnosis, ', ')
FROM hospital_readmission;

-- Q5: Date range
SELECT MIN(admission_date), MAX(admission_date) FROM hospital_readmission;

-- Q6: Numeric ranges (outlier detection)
SELECT MIN(age), MAX(age), ROUND(AVG(age),1), MIN(household_income), MAX(household_income)
FROM hospital_readmission;

---- Q7: Missing values
SELECT 
    COUNT(*) FILTER (WHERE household_income IS NULL) AS missing_income,
    COUNT(*) FILTER (WHERE comorbidity_score IS NULL) AS missing_comorbidity,
    COUNT(*) FILTER (WHERE total_bill_amount IS NULL) AS missing_bill
FROM hospital_readmission;


-- Q8: Length of stay distribution
SELECT (discharge_date - admission_date) AS los, COUNT(*)
FROM hospital_readmission
GROUP BY los
ORDER BY los;

-- Q9: Top diagnoses
SELECT primary_diagnosis, COUNT(*) 
FROM hospital_readmission
GROUP BY primary_diagnosis
ORDER BY COUNT(*) DESC;


-- Q10: Gender distribution
SELECT gender, COUNT(*), 
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)
FROM hospital_readmission
GROUP BY gender;

-- Q11. Derived Columns (Categorization)

SELECT 
    patient_id,
    age,
    CASE 
        WHEN age < 30 THEN 'Young Adult'
        WHEN age BETWEEN 30 AND 60 THEN 'Middle Age'
        WHEN age > 60 THEN 'Senior'
        ELSE 'Unknown'
    END as age_bracket
FROM hospital_readmission
GROUP BY 1,2
ORDER BY age;

-- Q12. Do richer patients get readmitted less? Task: Calculate readmission rate by Income Bracket.
SELECT 
    CASE 
        WHEN household_income < 40000 THEN 'Low Income'
        WHEN household_income < 80000 THEN 'Middle Income'
        ELSE 'High Income'
    END as income_tier,
    COUNT(*) as total_patients,
    SUM(readmitted_30_days) as readmitted_count,
    -- LOGIC: Average of a 1/0 column is the Rate %
    ROUND(AVG(readmitted_30_days) * 100, 2) as readmission_rate
FROM hospital_readmission
GROUP BY 1  -- Refers to the first column (CASE statement)
ORDER BY readmission_rate DESC;

-- Complex Joins & Subqueries
WITH FinancialStress AS (
    SELECT 
        patient_id,
        household_income,
        total_bill_amount,
        (total_bill_amount / NULLIF(household_income, 0)) as debt_ratio
    FROM hospital_readmission
)
SELECT * FROM FinancialStress
WHERE debt_ratio > 0.5;


WITH FinancialStress AS(
   SELECT 
      patient_id,
	  household_income,
	  total_bill_amount,
	  -- NULLIF: Prevents "Divide by Zero" errors if income is 0. 3.
	  ROUND(total_bill_amount / NULLIF (household_income,0)) as debt_ratio
	FROM hospital_readmission
)
SELECT * FROM FinancialStress
WHERE debt_ratio > 0.5;


-- To Compare Insured vs Uninsured:

SELECT 
    CASE 
        WHEN insurance_type IN ('Medicare', 'Private', 'Medicaid') THEN 'Insured'
        ELSE 'Uninsured'
    END as coverage_status,
    COUNT(*) as patients,
    ROUND(AVG(total_bill_amount), 0) as avg_bill
FROM hospital_readmission
GROUP BY coverage_status;


-- Comparative Analysis

SELECT 
    primary_diagnosis,
    ROUND(AVG(total_bill_amount) FILTER (WHERE insurance_type = 'Medicare'), 0) as medicare_avg,
    ROUND(AVG(total_bill_amount) FILTER (WHERE insurance_type = 'Private'), 0) as private_avg,
    ROUND(
        AVG(total_bill_amount) FILTER (WHERE insurance_type = 'Medicare') - 
        AVG(total_bill_amount) FILTER (WHERE insurance_type = 'Private'), 0
    ) as price_gap
FROM hospital_readmission
WHERE insurance_type IN ('Medicare', 'Private')
  AND primary_diagnosis = 'Heart Failure'
GROUP BY primary_diagnosis;




-- Ranking Analysis (Window Functions)
-- Scenario: Find the top 3 most expensive patients per region (or Diagnosis group). 
-- Task: Rank patients by bill amount, partitioned by diagnosis.

WITH RankedBills AS (
    SELECT 
        patient_id,
        primary_diagnosis,
        total_bill_amount,
        DENSE_RANK() OVER(
            PARTITION BY primary_diagnosis 
            ORDER BY total_bill_amount DESC
        ) as bill_rank
    FROM hospital_readmission
    WHERE total_bill_amount IS NOT NULL -- <--- Add this filter
)
SELECT * FROM RankedBills
WHERE bill_rank <= 3;




-- Length of Stay Outliers
-- Scenario: Who stays longer than the average for their condition? 
-- Task: Flag patients staying 2x longer than the average.

WITH StayAnalysis AS (
    SELECT 
        patient_id,
        primary_diagnosis,
        admission_date,
        discharge_date,
        (discharge_date - admission_date) as length_of_stay,  
        AVG(discharge_date - admission_date) OVER(PARTITION BY primary_diagnosis) as avg_benchmark
    FROM hospital_readmission
    WHERE discharge_date IS NOT NULL  
      AND admission_date IS NOT NULL
)
SELECT 
    patient_id,
    primary_diagnosis,
    admission_date,
    discharge_date,
    length_of_stay,  
    ROUND(avg_benchmark, 1) as avg_benchmark,
    ROUND(length_of_stay / avg_benchmark, 2) as stay_ratio,
    CASE 
        WHEN length_of_stay >= 2 * avg_benchmark THEN '🚨 Outlier (2x+)'
        WHEN length_of_stay >= 1.5 * avg_benchmark THEN '⚠️ Extended Stay (1.5x+)'
        ELSE '✅ Normal'
    END as stay_status
FROM StayAnalysis
ORDER BY stay_ratio DESC
LIMIT 20;




-- Moving Average
-- Scenario: Are bills getting more expensive as we process more patients (proxy for time)? 
-- Task: Calculate a running average of bill amounts.


SELECT 
    id, 
    admission_type, 
    total_bill_amount,
    -- LOGIC: Average of current row + previous 9 rows
    ROUND(AVG(total_bill_amount) OVER(ORDER BY id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW),2) as moving_avg_10
FROM hospital_readmission;


SELECT 
    id, 
    admission_date,
    admission_type, 
    total_bill_amount,
    ROUND(AVG(total_bill_amount) OVER(ORDER BY id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW), 2) as moving_avg_10,
    
    -- Compare current bill to moving average
    ROUND(total_bill_amount - AVG(total_bill_amount) OVER(ORDER BY id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW), 2) as deviation_from_avg,
    
    -- Percentage difference
    ROUND((total_bill_amount / AVG(total_bill_amount) OVER(ORDER BY id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) - 1) * 100, 2) as pct_diff,
    
    -- Flag unusual bills
    CASE 
        WHEN total_bill_amount > 1.5 * AVG(total_bill_amount) OVER(ORDER BY id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) 
        THEN '🚨 HIGH'
        WHEN total_bill_amount < 0.5 * AVG(total_bill_amount) OVER(ORDER BY id ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) 
        THEN '⬇️ LOW'
        ELSE '✅ Normal'
    END as bill_status
    
FROM hospital_readmission
ORDER BY id
LIMIT 50;


-- The "Frequent Flyer" Delta (LAG)
-- Scenario: A doctor asks, "Is this patient’s bill getting higher or lower compared to their last visit?"
-- Task: Calculate the difference in total_bill_amount between the current visit and the previous one for each patient.

SELECT 
    patient_id,
    admission_date,
    total_bill_amount,
    -- LOGIC: Look at the previous row's bill (partitioned by patient, ordered by date)
    LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date) as previous_bill,
    -- Calculate the difference
    total_bill_amount - LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date) as bill_change
FROM hospital_readmission;


WITH BillTrends AS (
    SELECT 
        patient_id,
        admission_date,
        total_bill_amount,
        LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date) as previous_bill,
        total_bill_amount - LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date) as bill_change,
        
        -- Percentage change
        ROUND(
            (total_bill_amount - LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date)) * 100.0 / 
            NULLIF(LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date), 0), 
            2
        ) as pct_change,
        
        -- Flag the trend
        CASE 
            WHEN LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date) IS NULL THEN '🆕 First Visit'
            WHEN total_bill_amount > LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date) THEN '📈 Increasing'
            WHEN total_bill_amount < LAG(total_bill_amount) OVER(PARTITION BY patient_id ORDER BY admission_date) THEN '📉 Decreasing'
            ELSE '➡️ Same'
        END as trend,
        
        ROW_NUMBER() OVER(PARTITION BY patient_id ORDER BY admission_date) as visit_number
        
    FROM hospital_readmission
)
SELECT * 
FROM BillTrends
WHERE trend = '🆕 First Visit'  -- ✅ Now you can filter by trend!
ORDER BY bill_change DESC;     -- Show biggest increases first



-- Running Totals (Cumulative Sum)
-- Scenario: Finance wants to see how our revenue accumulates throughout the month.
-- Task: Calculate a running total of total_bill_amount ordered by admission date.

SELECT 
    admission_date,
    total_bill_amount,
    SUM(total_bill_amount) OVER(
        PARTITION BY DATE_TRUNC('month', admission_date) -- <--- RESETS every month
        ORDER BY admission_date
    ) as monthly_cumulative_revenue
FROM hospital_readmission;

-- Percentile Ranking (Risk Stratification)
-- Scenario: We need to identify the top 5% most expensive patients for a "High Risk Care Management" program. 
-- Task: Assign a percentile (1-100) to each patient based on their total bill.

SELECT * FROM (
    SELECT 
        patient_id,
        total_bill_amount,
        primary_diagnosis,
        NTILE(100) OVER(ORDER BY total_bill_amount DESC) as cost_percentile
    FROM hospital_readmission
    WHERE total_bill_amount IS NOT NULL
) ranked
WHERE cost_percentile <= 5  -- ✅ Only keep percentiles 1, 2, 3, 4, 5
ORDER BY total_bill_amount DESC;

-- Readmission Intervals (Date Diff)
-- Scenario: How many days passed between a patient’s discharge and their next admission? 
-- Task: Calculate days_since_last_discharge.

-- Q1: How many readmissions are high-risk (≤30 days)?
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


-- Patient-level insights - Who's the "frequent flyer"?
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
        admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) 
            as days_gap
    FROM hospital_readmission
) gaps
WHERE days_gap IS NOT NULL
GROUP BY patient_id
HAVING COUNT(*) >= 3  -- Patients with 3+ readmissions
ORDER BY total_readmissions DESC
LIMIT 10;


-- Cohort Analysis (Retention)
-- Scenario: Of all patients admitted in January, how many returned in February? 
-- Task: Group patients by their "First Admission Month" (Cohort).
SELECT 
    DATE_TRUNC('month', admission_date) as admission_month,
    COUNT(DISTINCT patient_id) as distinct_patients
FROM hospital_readmission
GROUP BY 1
ORDER BY 1;



-- The "Weekend Effect"
-- Scenario: Do we have higher mortality/readmission rates for patients admitted on weekends? 
-- Task: Extract the day of the week and compare readmission rates.

SELECT 
    TO_CHAR(admission_date, 'Day') as day_of_week,
    COUNT(*) as admissions,
    ROUND(AVG(readmitted_30_days)*100, 2) as readmission_rate
FROM hospital_readmission
GROUP BY 1
ORDER BY readmission_rate DESC;


-- Creating a Standard View (The "Single Source of Truth")
-- Scenario: The "High Risk" logic (LACE score > 10, etc.) is complex.
-- You don't want to type it every time. Task: Create a VIEW that pre-calculates the risk flags.

CREATE OR REPLACE VIEW v_high_risk_patients AS
WITH CalculatedScore AS (
    SELECT 
        patient_id,
        primary_diagnosis,
        total_bill_amount,
        -- 1. Calculate Length of Stay (L)
        (discharge_date - admission_date) AS length_of_stay,
        
        -- 2. Calculate LACE Score Components
        (
            -- L: Length of stay (capped at typical LACE max of 7 for simplicity)
            LEAST((discharge_date - admission_date), 7) + 
            
            -- A: Acuity (3 points if Emergency, 0 otherwise) [3]
            CASE WHEN admission_type = 'Emergency' THEN 3 ELSE 0 END + 
            
            -- C: Comorbidity Score (normalized to standard scale) [1]
            LEAST(comorbidity_score, 5) + 
            
            -- E: Emergency visits in last 12m (capped at 4) [2]
            LEAST(previous_admissions_12m, 4)
        ) AS lace_score
    FROM hospital_readmission
)
SELECT 
    patient_id,
    primary_diagnosis,
    total_bill_amount,
    lace_score,
    -- Apply the Risk Logic on the calculated score
    CASE 
        WHEN lace_score > 10 THEN 'High'
        WHEN lace_score > 5 THEN 'Medium'
        ELSE 'Low'
    END as risk_category
FROM CalculatedScore;

SELECT * FROM v_high_risk_patients;




-- Materialized Views (Performance)
-- Scenario: The "Readmission Rate by Region" query takes 10 minutes to run because the dataset is huge (10M rows).
-- Task: Create a MATERIALIZED VIEW to cache the result.


CREATE MATERIALIZED VIEW mv_regional_stats AS
SELECT 
    hospital_region,
    COUNT(*) as total_patients,
    AVG(total_bill_amount) as avg_cost
FROM hospital_readmission
GROUP BY hospital_region;


SELECT * FROM mv_regional_stats


-- Pivot Tables (Crosstab)
-- Scenario: Management wants a report with "Months" as columns and "Insurance Type" as rows. 
-- Task: Pivot the data (Sum of bills). Note: In PostgreSQL, we often use FILTER for pivoting.
SELECT 
    insurance_type,
    SUM(total_bill_amount) FILTER (WHERE EXTRACT(MONTH FROM admission_date) = 1) as jan_revenue,
    SUM(total_bill_amount) FILTER (WHERE EXTRACT(MONTH FROM admission_date) = 2) as feb_revenue,
    SUM(total_bill_amount) FILTER (WHERE EXTRACT(MONTH FROM admission_date) = 3) as mar_revenue
FROM hospital_readmission
GROUP BY insurance_type;


-- Basic Stored Procedure (Reusable Script)
-- Scenario: We frequently need to discharge a patient and calculate their final bill. 
-- Task: Create a procedure discharge_patient that updates their status.

CREATE OR REPLACE PROCEDURE discharge_patient(
    p_patient_id VARCHAR, 
    p_disposition VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update the table
    UPDATE hospital_readmission
    SET discharge_disposition = p_disposition,
        -- FIX: Update discharge_date to be 5 days after admission
        discharge_date = admission_date + INTERVAL '5 days'
    WHERE patient_id = p_patient_id;
    
    -- Commit the change
    COMMIT;
END;
$$;

SELECT 
    patient_id, 
    discharge_disposition
    
FROM hospital_readmission 
WHERE patient_id = 'PAT00001';


-- Automation with Triggers (Audit Trails)
-- Scenario: If someone changes a patient's bill amount, we need a record of WHO did it and WHAT the old amount was.
-- Task: Create a trigger that logs changes to an audit_log table.

-- 1. Create the Log Table
CREATE TABLE bill_audit_log (
    log_id SERIAL PRIMARY KEY,
    patient_id VARCHAR,
    old_amount DECIMAL,
    new_amount DECIMAL,
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create the Function
CREATE OR REPLACE FUNCTION log_bill_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.total_bill_amount <> OLD.total_bill_amount THEN
        INSERT INTO bill_audit_log(patient_id, old_amount, new_amount)
        VALUES (OLD.patient_id, OLD.total_bill_amount, NEW.total_bill_amount);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Attach the Trigger
CREATE TRIGGER trg_bill_change
AFTER UPDATE ON hospital_readmission
FOR EACH ROW
EXECUTE FUNCTION log_bill_change();


-- 1. Manually Update a Bill Amount Run a direct SQL update to change the bill for a specific patient (e.g., changing it to 50000).
UPDATE hospital_readmission
SET total_bill_amount = 50000.00
WHERE patient_id = 'PAT00001';
-- 2. Verify the Audit Log Check the bill_audit_log table. If the trigger works, 
-- you should see a new row containing the patient_id, the old_amount (the value before your update), and the new_amount (50000.00).
SELECT * FROM bill_audit_log 
WHERE patient_id = 'PAT00001';



-- User Defined Function (UDF) - Scalar
-- Scenario: We need to calculate LACE Score in many different queries.
-- Task: Create a function get_lace_score(los, acuity, comorb, ed) that returns the score.

CREATE OR REPLACE FUNCTION calculate_lace(
    len_stay INT, 
    is_emergency BOOLEAN, 
    comorb_score INT, 
    ed_visits INT
)
RETURNS INT AS $$
DECLARE
    score INT := 0;
BEGIN
    -- Add Length of Stay points
    IF len_stay >= 14 THEN score := score + 7;
    ELSIF len_stay >= 7 THEN score := score + 5;
    ELSE score := score + len_stay;
    END IF;

    -- Add Acuity points
    IF is_emergency THEN score := score + 3; END IF;
    
    -- Add Comorbidity & ED points
    score := score + comorb_score + ed_visits;
    
    RETURN score;
END;
$$ LANGUAGE plpgsql;

-- Recursive CTE (Hierarchy)
-- Scenario: A patient was referred by Doctor A, who was referred by Doctor B. Trace the referral chain.
-- Task: Use a Recursive CTE to find the "Patient Zero" or top-level doctor. (Assuming a referral_table exists).

-- 1. Create the table
DROP TABLE IF EXISTS doctors;

CREATE TABLE doctors (
    doctor_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    specialty VARCHAR(50),
    referred_by_id INTEGER -- This is the "Parent" ID (Who hired/referred them?)
);

-- 2. Insert Hierarchical Data
INSERT INTO doctors (doctor_id, name, specialty, referred_by_id) VALUES
(1, 'Dr. Gregory House', 'Diagnostic Medicine', NULL), -- The Big Boss (No referrer)
(2, 'Dr. Lisa Cuddy', 'Endocrinology', 1),           -- Referred by House
(3, 'Dr. James Wilson', 'Oncology', 1),              -- Referred by House
(4, 'Dr. Eric Foreman', 'Neurology', 2),             -- Referred by Cuddy
(5, 'Dr. Allison Cameron', 'Immunology', 2),         -- Referred by Cuddy
(6, 'Dr. Robert Chase', 'Intensive Care', 3),        -- Referred by Wilson
(7, 'Dr. Remy Hadley', 'Internal Medicine', 4),      -- Referred by Foreman
(8, 'Dr. Chris Taub', 'Plastic Surgery', 4),         -- Referred by Foreman
(9, 'Dr. Lawrence Kutner', 'Sports Medicine', 6);    -- Referred by Chase




WITH RECURSIVE ReferralChain AS (
    -- ANCHOR: Start with the specific doctor (Dr. Kutner)
    SELECT 
        doctor_id, 
        name, 
        specialty, 
        referred_by_id,
        1 as level -- Level 1 = The Doctor himself
    FROM doctors
    WHERE doctor_id = 9
    
    UNION ALL
    
    -- RECURSIVE MEMBER: Join the CTE back to the main table
    -- Find the doctor who is the "referred_by_id" of the previous row
    SELECT 
        d.doctor_id, 
        d.name, 
        d.specialty, 
        d.referred_by_id,
        rc.level + 1 as level
    FROM doctors d
    INNER JOIN ReferralChain rc ON d.doctor_id = rc.referred_by_id
)
SELECT * FROM ReferralChain;



-- The "EXPLAIN" Plan
/*Scenario: Your query for readmission_rate takes 10 seconds. You need to know why.
Task: Generate an execution plan to see if the database is doing a "Seq Scan" 
(reading every single row) or an "Index Scan" (jumping straight to the answer).*/

EXPLAIN ANALYZE -- <--- This is the magic command
SELECT * FROM hospital_readmission 
WHERE patient_id = 'PAT00500';


-- Creating Indexes (The Speed Boost)
-- Scenario: You discovered (in Q31) that searching by primary_diagnosis is slow because there is no index.
-- Task: Create an index to speed up diagnosis filtering.

CREATE INDEX idx_diagnosis ON hospital_readmission(primary_diagnosis);


-- . EXISTS vs IN (Optimization)
-- Scenario: Find all patients who have also had a banking delinquency (using your other table).
-- Task: Write this query efficiently. Beginners use IN. Experts use EXISTS.

-- SLOW WAY (The Beginner)
-- 1. Create the missing Banking Table
CREATE TABLE IF NOT EXISTS delinquency_prediction (
    customer_id VARCHAR(20) PRIMARY KEY,
    delinquent_account INTEGER
);

-- 2. Insert some matching IDs (so the query actually finds something)
INSERT INTO delinquency_prediction (customer_id, delinquent_account)
SELECT 
    patient_id, -- We use the same IDs as the hospital table so they match
    CASE WHEN random() < 0.2 THEN 1 ELSE 0 END -- Random delinquency
FROM hospital_readmission
LIMIT 500; -- Create 500 banking records

-- check 
SELECT * FROM hospital_readmission 
WHERE patient_id IN (SELECT customer_id FROM delinquency_prediction);

-- EXPERT WAY: Using EXISTS
SELECT * FROM hospital_readmission h
WHERE EXISTS (
    SELECT 1 
    FROM delinquency_prediction d 
    WHERE d.customer_id = h.patient_id
);


-- Sessionization (Gaps and Islands)
-- Scenario: A patient is in the hospital. If they leave and return within 24 hours, 
-- it's the same visit (continuing care). If they return after 3 days, it's a new visit.
-- Task: Group admission rows into "Episodes of Care".

WITH Gaps AS (
    SELECT
        patient_id,
        admission_date,
        discharge_date,
        -- Calculate the gap first (no nesting here)
        admission_date - LAG(discharge_date) OVER(
            PARTITION BY patient_id 
            ORDER BY admission_date
        ) as days_since_last_discharge
    FROM hospital_readmission
)
SELECT
    patient_id,
    admission_date,
    discharge_date,
    days_since_last_discharge,
    -- Now use the pre-calculated gap in the SUM
    SUM(CASE
        WHEN days_since_last_discharge <= 1 THEN 0 
        ELSE 1
    END) OVER(
        PARTITION BY patient_id 
        ORDER BY admission_date
    ) as episode_id
FROM Gaps;


-- Churn Analysis (Retention)
-- Scenario: A "Churned" patient is one who hasn't visited in 365 days.
-- Task: Identify patients who are currently "Active" vs "Churned".

SELECT 
    patient_id,
    MAX(admission_date) as last_visit,
    CASE 
        WHEN MAX(admission_date) < CURRENT_DATE - INTERVAL '1 year' THEN 'Churned'
        ELSE 'Active'
    END as status
FROM hospital_readmission
GROUP BY patient_id;

-- Basket Analysis (Co-occurrence)
-- Scenario: What diagnoses often occur together in the same patient? (e.g., Diabetes + Hypertension).
-- Task: Find pairs of diagnoses for the same patient.

SELECT 
    a.primary_diagnosis as condition_1,
    b.primary_diagnosis as condition_2,
    COUNT(*) as frequency
FROM hospital_readmission a
JOIN hospital_readmission b 
    ON a.patient_id = b.patient_id 
    AND a.primary_diagnosis < b.primary_diagnosis -- Avoid duplicates (A-B and B-A)
GROUP BY 1, 2
ORDER BY frequency DESC
LIMIT 5;


-- Z-Score (Outlier Detection)
-- Scenario: Find bills that are statistically anomalous (3 Standard Deviations above the mean).
-- Task: Calculate Z-Score for every bill.

WITH Stats AS (
    SELECT 
        AVG(total_bill_amount) as mean, 
        STDDEV(total_bill_amount) as sd
    FROM hospital_readmission
    WHERE total_bill_amount IS NOT NULL  -- Exclude NULLs from calculation
)
SELECT 
    h.patient_id,
    h.total_bill_amount,
    ROUND(s.mean, 2) as population_mean,
    ROUND(s.sd, 2) as standard_deviation,
    ROUND((h.total_bill_amount - s.mean) / s.sd, 2) as z_score,
    CASE 
        WHEN (h.total_bill_amount - s.mean) / s.sd > 3 THEN '🚨 Extreme Outlier (3σ+)'
        WHEN (h.total_bill_amount - s.mean) / s.sd > 2 THEN '⚠️ Moderate Outlier (2σ+)'
        WHEN (h.total_bill_amount - s.mean) / s.sd > 1 THEN '⬆️ Above Average (1σ+)'
        WHEN (h.total_bill_amount - s.mean) / s.sd < -1 THEN '⬇️ Below Average (-1σ)'
        ELSE '✅ Normal Range'
    END as outlier_status
FROM hospital_readmission h
CROSS JOIN Stats s
WHERE h.total_bill_amount IS NOT NULL  -- Exclude NULLs from results
ORDER BY z_score DESC;


-- Parsing JSON (NoSQL in SQL)
-- Scenario: The day_1 to day_7 vitals are stored in a single JSON column vitals_json (e.g., {"bp": "120/80", "temp": 98.6}).
-- Task: Extract temp where it is > 100 (Fever).


-- Assuming a column 'vitals' exists as JSONB type
-- Create the patient_logs table with JSONB vitals column
CREATE TABLE IF NOT EXISTS patient_logs (
    id SERIAL PRIMARY KEY,
    patient_id VARCHAR(20),
    vitals JSONB,  -- JSONB = Binary JSON (faster, indexable)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data with fever and normal temps
INSERT INTO patient_logs (patient_id, vitals) VALUES
('PAT00001', '{"bp": "120/80", "temp": 98.6, "hr": 72}'),
('PAT00002', '{"bp": "140/90", "temp": 101.5, "hr": 88}'),  -- Fever
('PAT00003', '{"bp": "110/70", "temp": 102.3, "hr": 95}'),  -- Fever
('PAT00004', '{"bp": "130/85", "temp": 99.1, "hr": 76}');

-- Now run your query
SELECT 
    patient_id,
    vitals ->> 'temp' as temperature
FROM patient_logs
WHERE (vitals ->> 'temp')::numeric > 100;

-- Array Aggregation (List creation)
-- Scenario: Doctors want a single row per patient with a comma-separated list of all their diagnoses.
-- Task: Collapse multiple rows into one string.

SELECT 
    patient_id,
    STRING_AGG(primary_diagnosis, ', ' ORDER BY admission_date) as diagnosis_history
FROM hospital_readmission
GROUP BY patient_id;

-- Unnesting Arrays (Normalization)
-- Scenario: You have a list ['Flu', 'Cough'] in one cell. You need to count how many people have 'Flu'.
-- Task: Explode the array into rows.


-- Create patient_surveys table
CREATE TABLE IF NOT EXISTS patient_surveys (
    id SERIAL PRIMARY KEY,
    patient_id VARCHAR(20),
    diagnosis_list TEXT  -- Comma-separated values like 'Flu,Cough,Fever'
);

-- Insert sample data
INSERT INTO patient_surveys (patient_id, diagnosis_list) VALUES
('PAT00001', 'Flu,Cough'),
('PAT00002', 'Flu,Fever'),
('PAT00003', 'Cough,Asthma'),
('PAT00004', 'Flu,Covid'),
('PAT00005', 'Diabetes,Hypertension');

-- Now run your query
SELECT
    UNNEST(string_to_array(diagnosis_list, ',')) as single_diagnosis,
    COUNT(*)
FROM patient_surveys
GROUP BY 1;

-- Use Your Existing hospital_readmission Table

-- Create a subquery with aggregated diagnoses, then unnest
WITH diagnosis_aggregated AS (
    SELECT 
        patient_id,
        STRING_AGG(primary_diagnosis, ', ') as diagnosis_list
    FROM hospital_readmission
    GROUP BY patient_id
    HAVING COUNT(*) > 1  -- Only patients with multiple diagnoses
)
SELECT
    TRIM(UNNEST(string_to_array(diagnosis_list, ','))) as single_diagnosis,
    COUNT(*) as patient_count
FROM diagnosis_aggregated
GROUP BY 1
ORDER BY 2 DESC;

-- Regex Matching (Pattern Matching)
-- Scenario: Find patients whose chart notes mention "chest pain" or "angina" (case insensitive).
-- Task: Use Regex.

SELECT * FROM hospital_readmission
WHERE primary_diagnosis ~* 'chest pain|angina';

-- . Pivot with JSON (Dynamic Columns)
-- Scenario: Return a JSON object for each patient summarizing their spend.
-- Task: Create a JSON summary.
SELECT 
    patient_id,
    json_build_object(
        'total_spent', SUM(total_bill_amount),
        'visits', COUNT(*)
    ) as patient_summary
FROM hospital_readmission
GROUP BY patient_id;


-- Cumulative Distribution Function (CDF)
-- Scenario: What is the bill amount for the bottom 80% of patients? (Pareto analysis).
-- Task: Calculate CUME_DIST.
SELECT 
    patient_id,
    total_bill_amount,
    CUME_DIST() OVER(ORDER BY total_bill_amount) as cdf
FROM hospital_readmission;


-- The Final Automated Report
-- Scenario: Create a single query that outputs: Total Revenue, Total Patients, Readmission Rate, and Top Diagnosis.
-- Task: Use CTEs to combine unrelated metrics into one dashboard row.


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
FROM Financials, Volume, Rates, TopDiag; -- Cartesian Join (Safe for single rows)





-- The "Personal Insurance" Penetration
-- Insight: How many people actually have Private Insurance vs. relying on the Government (Medicare/Medicaid)?
-- This tells us about the economic stability of your patient base.	

SELECT 
    insurance_type,
    COUNT(*) as total_patients,
    -- Calculate the % of total
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) as market_share
FROM hospital_readmission
GROUP BY insurance_type
ORDER BY total_patients DESC;

-- The "Complex Chronic" (High BP + Other Diseases)
-- Insight: You asked: "How many have High BP + other diseases?"
-- Since primary_diagnosis only shows one thing, we use comorbidity_score > 2 to prove they have other underlying issues.

SELECT 
    COUNT(*) as complex_patients,
    ROUND(AVG(total_bill_amount), 0) as avg_cost
FROM hospital_readmission
WHERE primary_diagnosis LIKE '%Hypertension%' -- Or 'Heart Failure'
  AND comorbidity_score >= 3; -- <--- This means "Plus Other Diseases"


-- The "Multi-System" Failure (Different Diagnoses over Time)
-- Insight: Patients who come in for Heart issues in Jan and Lung issues in March are deteriorating.

SELECT 
    patient_id,
    COUNT(DISTINCT primary_diagnosis) as unique_conditions
FROM hospital_readmission
GROUP BY patient_id
HAVING COUNT(DISTINCT primary_diagnosis) > 1 -- Visited for at least 2 DIFFERENT reasons
ORDER BY unique_conditions DESC;


-- The "Young & Sick" (Genetic/Lifestyle Anomalies)
-- Insight: It's normal for an 80-year-old to have a high comorbidity score. 
-- It is NOT normal for a 30-year-old. These are high-risk outliers.

SELECT 
    patient_id,
    age,
    primary_diagnosis,
    comorbidity_score
FROM hospital_readmission
WHERE age < 40 
  AND comorbidity_score > 4 -- Very sick for a young person
ORDER BY comorbidity_score DESC;


-- The "Rich but Sick" Paradox (Income vs. Health)
-- Insight: Do wealthier people typically have lower comorbidity scores? (Testing the "Wealth = Health" hypothesis).

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


-- The "Weekend Warrior" Effect
-- Insight: Do we get different types of patients on weekends? (e.g., more trauma/accidents, less elective surgery).

SELECT 
    CASE 
        WHEN EXTRACT(ISODOW FROM admission_date) IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    primary_diagnosis,
    COUNT(*) as admissions
FROM hospital_readmission
GROUP BY 1, 2
ORDER BY 1, 3 DESC;


-- The "Profitable" Patient
-- Insight: Which diagnosis brings in the most revenue relative to how long they stay? (High Revenue / Low Stay = Efficient).

SELECT 
    primary_diagnosis,
    ROUND(AVG(total_bill_amount), 0) as revenue,
    ROUND(AVG(length_of_stay), 1) as days,
    -- Revenue per Day (Efficiency Metric)
    ROUND(AVG(total_bill_amount) / NULLIF(AVG(length_of_stay), 0), 0) as rev_per_day
FROM hospital_readmission
GROUP BY primary_diagnosis
ORDER BY rev_per_day DESC;

-- Insurance "Denial" Risk
-- Insight: Patients with "Self-Pay" (No Insurance) and high bills are essentially "Bad Debt" (unlikely to pay).

SELECT 
    patient_id,
    total_bill_amount,
    household_income
FROM hospital_readmission
WHERE insurance_type = 'Self-Pay'
  AND total_bill_amount > (household_income * 0.20) -- Bill is >20% of their annual salary
ORDER BY total_bill_amount DESC;



-- The "Frequent Flyer" Cost
-- Insight: How much of our total budget is consumed by the top 1% of patients? (Pareto Principle).

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

-- Predicting Next Month's Crash (Trend Analysis)
-- Insight: Are readmissions trending UP or DOWN over the last 3 months?

SELECT 
    DATE_TRUNC('month', admission_date) as month,
    AVG(readmitted_30_days) as readmission_rate,
    -- Compare current month to previous month
    AVG(readmitted_30_days) - LAG(AVG(readmitted_30_days)) OVER(ORDER BY DATE_TRUNC('month', admission_date)) as rate_change
FROM hospital_readmission
GROUP BY 1
ORDER BY 1 DESC;

-- The "Risk Score" Algorithm (Feature Engineering)
-- Scenario: Doctors can't look at 50 columns. They need ONE number (0-100) to decide if a patient is safe to leave.
-- Task: Create a weighted scoring model based on clinical factors.

-- Age > 70: +20 points
-- Heart Failure: +30 points
-- Emergency Admit: +10 points
-- LACE Score > 10: +40 points


WITH RiskCalc AS (
    SELECT 
        patient_id,
        age,
        primary_diagnosis,
        (
            CASE WHEN age > 70 THEN 20 ELSE 0 END +
            CASE WHEN primary_diagnosis LIKE '%Heart Failure%' THEN 30 ELSE 0 END +
            CASE WHEN admission_type = 'Emergency' THEN 10 ELSE 0 END +
            CASE WHEN calculate_lace(
                    (discharge_date - admission_date),
                    (admission_type = 'Emergency'),
                    comorbidity_score,
                    previous_admissions_12m
                ) > 10 THEN 40 ELSE 0 END +
            (COALESCE(comorbidity_score, 0) * 5)
        ) as predictive_risk_score
    FROM hospital_readmission
)
SELECT 
    patient_id,
    age,
    primary_diagnosis,
    predictive_risk_score,
    CASE 
        WHEN predictive_risk_score >= 80 THEN '🔴 High Risk'
        WHEN predictive_risk_score >= 50 THEN '🟡 Medium Risk'
        ELSE '🟢 Low Risk'
    END as risk_category
FROM RiskCalc
ORDER BY predictive_risk_score DESC;





