# 🚀 Quick Setup Guide

## Prerequisites

- PostgreSQL 12 or higher
- psql command-line tool
- Basic SQL knowledge

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/hospital-readmission-analysis.git
cd hospital-readmission-analysis
```

### 2. Create Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE hospital_analytics;

# Connect to the new database
\c hospital_analytics
```

### 3. Load the Data

```bash
# Execute the table creation and data generation script
psql -U postgres -d hospital_analytics -f sql/01_table_creation_and_data.sql
```

This will:
- Create the `hospital_readmission` table
- Generate 5,000 synthetic patient records
- Add realistic missing values and outliers

### 4. Verify Data Load

```sql
-- Check row count
SELECT COUNT(*) FROM hospital_readmission;
-- Expected: 5000

-- View sample records
SELECT * FROM hospital_readmission LIMIT 10;

-- Check for NULL values
SELECT 
    COUNT(*) FILTER (WHERE household_income IS NULL) as null_income,
    COUNT(*) FILTER (WHERE comorbidity_score IS NULL) as null_comorbidity
FROM hospital_readmission;
```

### 5. Run Example Queries

```bash
# Run all analytical queries
psql -U postgres -d hospital_analytics -f sql/01_table_creation_and_data.sql

# Run readmission analysis
psql -U postgres -d hospital_analytics -f sql/04_readmission_analysis.sql
```

## File Structure

```
hospital-readmission-analysis/
│
├── README.md                          # Main documentation (start here!)
├── LICENSE                            # MIT License
├── SETUP.md                           # This file
│
├── sql/                               # SQL query files
│   ├── 01_table_creation_and_data.sql # Database schema + data generation
│   ├── 04_readmission_analysis.sql    # Readmission interval analysis
│   └── 05_advanced_analytics.sql      # Advanced queries and fixes
│
└── docs/                              # Documentation
    ├── QUERY_REFERENCE.md             # Complete query documentation
    └── BUSINESS_GLOSSARY.md           # Healthcare terminology
```

## Running Specific Queries

### Example 1: Overall Readmission Rate

```sql
SELECT 
    COUNT(*) as total_patients,
    SUM(readmitted_30_days) as total_readmissions,
    ROUND(AVG(readmitted_30_days) * 100, 2) as readmission_rate_pct
FROM hospital_readmission;
```

### Example 2: High-Risk Patients

```sql
SELECT 
    patient_id,
    age,
    comorbidity_score,
    primary_diagnosis,
    missed_medications
FROM hospital_readmission
WHERE comorbidity_score > 10 
  AND missed_medications > 3
ORDER BY comorbidity_score DESC;
```

### Example 3: Readmission Timing

```sql
SELECT 
    patient_id,
    admission_date,
    LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as prev_discharge,
    admission_date - LAG(discharge_date) OVER(PARTITION BY patient_id ORDER BY admission_date) as days_gap
FROM hospital_readmission
ORDER BY patient_id, admission_date;
```

## Troubleshooting

### Error: "relation does not exist"
**Solution**: Make sure you've run `01_table_creation_and_data.sql` first to create the table.

### Error: "permission denied"
**Solution**: Ensure your PostgreSQL user has CREATE, INSERT, SELECT privileges.

```sql
GRANT ALL PRIVILEGES ON DATABASE hospital_analytics TO your_username;
```

### No data returned
**Solution**: Check if data was loaded:

```sql
SELECT COUNT(*) FROM hospital_readmission;
```

If 0, re-run the data generation script.

## Next Steps

1. **Explore the Data**: Start with the README.md for an overview
2. **Learn the Queries**: Review docs/QUERY_REFERENCE.md for detailed explanations
3. **Understand Healthcare Terms**: Check docs/BUSINESS_GLOSSARY.md
4. **Customize**: Modify queries for your specific analysis needs

## Database Performance Tips

### Add Indexes for Better Performance

```sql
-- Index for patient lookups
CREATE INDEX idx_patient_id ON hospital_readmission(patient_id);

-- Index for date-based queries
CREATE INDEX idx_admission_date ON hospital_readmission(admission_date);

-- Composite index for window functions
CREATE INDEX idx_patient_admission ON hospital_readmission(patient_id, admission_date);

-- Index for diagnosis queries
CREATE INDEX idx_primary_diagnosis ON hospital_readmission(primary_diagnosis);
```

### Check Query Performance

```sql
EXPLAIN ANALYZE
SELECT ...;
```

## Support

- **Issues**: Open an issue on GitHub
- **Questions**: Check the documentation first
- **Contributions**: Pull requests welcome!

## Learning Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Window Functions Tutorial](https://www.postgresql.org/docs/current/tutorial-window.html)
- [Healthcare Analytics Basics](https://www.healthcatalyst.com/insights)

---

**Ready to start? Open README.md and follow the query examples!**
