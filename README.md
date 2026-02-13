# Mobile Measurement Data Pipeline

A production-ready data pipeline for mobile measurement analytics using Google Cloud Platform (GCS, BigQuery, DBT). This pipeline generates synthetic mobile measurement partner (MMP) data, transforms it into actionable business metrics, and loads it into BigQuery for dashboard consumption.

## Overview

This pipeline addresses the need to validate app growth metrics with a "level of truth" for mobile measurement businesses. It demonstrates:

- **Data Generation**: Synthetic MMP events with realistic distributions
- **Data Storage**: Google Cloud Storage (JSONL format)
- **Data Transformation**: DBT models with staging → intermediate → marts architecture
- **Data Warehouse**: BigQuery for analytics and BI tool integration
- **Business Metrics**: Installs/Reinstalls, Click-Through Rate (CTR), Cost Per Install (CPI)

## Architecture

```
┌─────────────────┐
│ Python Generator│  Generates 100 synthetic MMP events
│   (event_gen)   │  with realistic distributions
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Google Cloud   │  Stores raw JSONL files
│    Storage      │  (gs://bucket/raw/*.jsonl)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    BigQuery     │  External table pointing to GCS
│  (External)     │  Auto-schema detection
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   DBT Models    │  Staging → Intermediate → Marts
│  Transformation │  Daily/Weekly/Monthly aggregations
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    BigQuery     │  Analytics-ready tables
│   (Native)      │  Ready for Looker/dashboards
└─────────────────┘
```

## Project Structure

```
mobile-measurement-pipeline/
├── src/
│   ├── config.py                     # GCP configuration
│   ├── generator/
│   │   ├── event_generator.py       # Main data generation script
│   │   └── mmp_config.py            # MMP constants & distributions
│   └── utils/
│       ├── gcs_uploader.py          # GCS upload utilities
│       └── validation.py            # Data validation
├── dbt_project/
│   ├── dbt_project.yml              # DBT configuration
│   ├── profiles.yml.template        # BigQuery connection template
│   ├── models/
│   │   ├── staging/
│   │   │   └── stg_mmp_events.sql   # Clean raw events
│   │   ├── intermediate/
│   │   │   ├── int_daily_metrics.sql
│   │   │   ├── int_weekly_metrics.sql
│   │   │   └── int_monthly_metrics.sql
│   │   └── marts/
│   │       ├── mart_installs_reinstalls.sql
│   │       ├── mart_click_through_rate.sql
│   │       └── mart_cost_per_install.sql
│   └── macros/
│       └── grain_aggregator.sql     # Reusable aggregation logic
├── setup/
│   ├── gcp_setup.bat                # Windows GCP setup
│   ├── gcp_setup.sh                 # Linux/Mac GCP setup
│   └── setup_instructions.md        # Manual setup guide
├── tests/
│   ├── test_event_generator.py      # Unit tests
│   └── validation_queries.sql       # BigQuery validation queries
├── requirements.txt                  # Python dependencies
├── .env.template                     # Environment variables template
└── README.md                         # This file
```

## Prerequisites

- **Google Cloud Platform account** with billing enabled
- **Python 3.8+** installed
- **gcloud CLI** installed and authenticated
- **bq CLI** (included with gcloud SDK)
- **Git** (optional, for version control)

## Quick Start

### 1. Clone/Create Project Directory

```bash
# Windows
mkdir C:\Users\Admin\Desktop\repo\mobile-measurement-pipeline
cd C:\Users\Admin\Desktop\repo\mobile-measurement-pipeline

# Linux/Mac
mkdir -p ~/projects/mobile-measurement-pipeline
cd ~/projects/mobile-measurement-pipeline
```

### 2. Install Dependencies

```bash
# Install Python packages
pip install -r requirements.txt

# Install DBT for BigQuery
pip install dbt-bigquery==1.7.0
```

### 3. Set Up GCP Resources

**Option A: Automated Setup (Recommended)**

```bash
# Windows
cd setup
.\gcp_setup.bat

# Linux/Mac
cd setup
export GCP_PROJECT_ID=your-project-id
chmod +x gcp_setup.sh
./gcp_setup.sh
```

**Option B: Manual Setup**

Follow the detailed instructions in [setup/setup_instructions.md](setup/setup_instructions.md).

### 4. Configure Environment Variables

Create `.env` file in project root:

```bash
GCP_PROJECT_ID=your-gcp-project-id
GCS_BUCKET=mobile-measurement-data
BQ_DATASET=mobile_measurement
GCP_REGION=us-central1
GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\service-account-key.json
```

### 5. Configure DBT Profile

Copy DBT profile template:

```bash
# Windows
copy dbt_project\profiles.yml.template %USERPROFILE%\.dbt\profiles.yml

# Linux/Mac
cp dbt_project/profiles.yml.template ~/.dbt/profiles.yml
```

Edit `~/.dbt/profiles.yml` and ensure environment variables are set correctly.

### 6. Generate and Upload Data

```bash
python src/generator/event_generator.py --num-events 100 --bucket mobile-measurement-data
```

**Expected Output:**
```
============================================================
MOBILE MEASUREMENT EVENT GENERATOR
============================================================

Generating 100 mobile measurement events...
  Progress: 100/100 events generated
✓ All 100 events validated successfully

============================================================
EVENT GENERATION SUMMARY
============================================================

Total Events: 100

Event Type Distribution:
  impression  :  60 events ( 60.0%)
  click       :  25 events ( 25.0%)
  install     :  12 events ( 12.0%)
  reinstall   :   3 events (  3.0%)

Total Cost: $256.42
Average Cost per Event: $2.56

✓ Local backup saved: data/raw/mmp_events_20260212_143045.jsonl
✓ Successfully uploaded to gs://mobile-measurement-data/raw/mmp_events_20260212_143045.jsonl
✓ Upload complete!
  GCS URI: gs://mobile-measurement-data/raw/mmp_events_20260212_143045.jsonl
  File size: 15.2 KB
  Event count: 100

✓ Event generation complete!
```

### 7. Create BigQuery External Table

```bash
bq mk \
  --external_table_definition=@NEWLINE_DELIMITED_JSON=gs://mobile-measurement-data/raw/*.jsonl \
  mobile_measurement.mmp_events_external
```

Verify table creation:

```bash
bq show mobile_measurement.mmp_events_external
bq head -n 10 mobile_measurement.mmp_events_external
```

### 8. Run DBT Transformations

```bash
cd dbt_project

# Install DBT packages
dbt deps

# Test connection
dbt debug

# Run all models and tests
dbt build

# Generate documentation (optional)
dbt docs generate
dbt docs serve
```

**Expected Output:**
```
Running with dbt=1.7.0
Found 7 models, 15 tests, 0 snapshots, 0 analyses, 0 macros, 0 operations, 0 seed files, 3 sources

Concurrency: 4 threads

Starting DBT run...
14:30:00 | Running with dbt=1.7.0
14:30:01 | 1 of 7 START sql view model staging.stg_mmp_events ............. [RUN]
14:30:02 | 1 of 7 OK created sql view model staging.stg_mmp_events ........ [OK in 1.2s]
14:30:02 | 2 of 7 START sql table model intermediate.int_daily_metrics .... [RUN]
14:30:03 | 3 of 7 START sql table model intermediate.int_weekly_metrics ... [RUN]
14:30:04 | 4 of 7 START sql table model intermediate.int_monthly_metrics .. [RUN]
14:30:05 | 2 of 7 OK created sql table model intermediate.int_daily_metrics [OK in 3.1s]
14:30:06 | 3 of 7 OK created sql table model intermediate.int_weekly_metrics [OK in 3.2s]
14:30:07 | 4 of 7 OK created sql table model intermediate.int_monthly_metrics [OK in 3.0s]
14:30:07 | 5 of 7 START sql table model marts.mart_installs_reinstalls .... [RUN]
14:30:08 | 6 of 7 START sql table model marts.mart_click_through_rate ..... [RUN]
14:30:09 | 7 of 7 START sql table model marts.mart_cost_per_install ....... [RUN]
14:30:10 | 5 of 7 OK created sql table model marts.mart_installs_reinstalls [OK in 2.8s]
14:30:11 | 6 of 7 OK created sql table model marts.mart_click_through_rate [OK in 2.9s]
14:30:12 | 7 of 7 OK created sql table model marts.mart_cost_per_install .. [OK in 2.7s]

Completed successfully

Done. PASS=7 WARN=0 ERROR=0 SKIP=0 TOTAL=7
```

### 9. Verify Results

Run validation queries:

```bash
# From BigQuery console or CLI
bq query --use_legacy_sql=false < tests/validation_queries.sql
```

Or use BigQuery console to query:

```sql
-- Check record count
SELECT COUNT(*) FROM `mobile_measurement.stg_mmp_events`;

-- View mart data
SELECT * FROM `mobile_measurement.mart_click_through_rate` WHERE grain = 'daily' LIMIT 10;
```

## Business Metrics

The pipeline produces three key analytics-ready marts:

### 1. Installs & Reinstalls (`mart_installs_reinstalls`)

Tracks app acquisition volume across time periods.

**Columns:**
- `grain`: Time aggregation (daily, weekly, monthly)
- `period`: Date identifier
- `partner`: MMP partner name
- `platform`: iOS or Android
- `installs`: Count of new installs
- `reinstalls`: Count of reinstalls
- `total_install_events`: Sum of installs + reinstalls
- `total_install_cost`: Total cost for acquisition events

**Use Cases:**
- Track install volume trends over time
- Compare partner performance
- Identify platform preferences

### 2. Click-Through Rate (`mart_click_through_rate`)

Measures ad engagement effectiveness.

**Columns:**
- `grain`: Time aggregation
- `period`: Date identifier
- `partner`: MMP partner
- `platform`: iOS or Android
- `clicks`: Count of click events
- `impressions`: Count of impression events
- `ctr`: Click-through rate (decimal)
- `ctr_percentage`: CTR as percentage (0-100)

**Use Cases:**
- Monitor ad creative performance
- Optimize campaign targeting
- Identify high-performing partners

**Expected CTR:** 2-5% (realistic for mobile ads)

### 3. Cost Per Install (`mart_cost_per_install`)

Evaluates user acquisition cost efficiency.

**Columns:**
- `grain`: Time aggregation
- `period`: Date identifier
- `partner`: MMP partner
- `platform`: iOS or Android
- `installs`: Count of installs
- `install_cost`: Direct cost of installs
- `total_cost`: Total spend (including impressions/clicks)
- `cpi_direct`: Cost per install (install cost / installs)
- `cpi_blended`: Blended CPI (total cost / installs)

**Use Cases:**
- Budget allocation optimization
- Partner cost comparison
- ROI analysis

**Expected CPI:** $1.50 - $8.00 (varies by platform and partner)

## Data Quality & Testing

### Automated Tests

The pipeline includes comprehensive data quality tests:

**Staging Layer Tests:**
- Unique event IDs
- Non-null required fields
- Valid event types
- Non-negative costs
- Valid platforms

**Marts Layer Tests:**
- CTR between 0-100%
- Impressions ≥ clicks
- CPI ≥ 0
- Blended CPI ≥ direct CPI

Run tests:

```bash
cd dbt_project
dbt test
```

### Manual Validation

Use the provided validation queries in `tests/validation_queries.sql`:

1. **Record Count Check** - Verify 100 events loaded
2. **Event Distribution** - Check ~60% impressions, ~25% clicks
3. **Partner Distribution** - Validate market share weights
4. **CTR Validation** - Ensure 2-5% CTR range
5. **CPI Validation** - Ensure $1.50-$8.00 range
6. **Grain Coverage** - Verify daily/weekly/monthly data

## Extending the Pipeline

### Adding New Metrics

1. Create a new model in `dbt_project/models/marts/`
2. Reference intermediate models using `{{ ref('int_daily_metrics') }}`
3. Add schema documentation in `_marts.yml`
4. Run `dbt build` to materialize

Example:

```sql
-- dbt_project/models/marts/mart_return_on_ad_spend.sql
SELECT
    grain,
    period,
    partner,
    SUM(revenue) / SUM(total_cost) AS roas
FROM {{ ref('int_daily_metrics') }}
GROUP BY grain, period, partner
```

### Incremental Processing

For production use, convert models to incremental:

```sql
{{
    config(
        materialized='incremental',
        unique_key='event_id',
        partition_by={'field': 'event_date', 'data_type': 'date'}
    )
}}

SELECT * FROM {{ ref('stg_mmp_events') }}
{% if is_incremental() %}
WHERE event_date > (SELECT MAX(event_date) FROM {{ this }})
{% endif %}
```

### Scheduling with Airflow/Cloud Composer

1. Create DAG for data generation
2. Trigger DBT runs using `BashOperator`
3. Add data quality checks with `BigQueryCheckOperator`
4. Set up alerting for failures

## Looker Integration

Once the pipeline is running, connect Looker to BigQuery:

1. **Add BigQuery Connection** in Looker
   - Project: Your GCP project ID
   - Dataset: `mobile_measurement`
   - Authentication: Service account JSON key

2. **Create LookML Models** for each mart table
   ```lookml
   view: mart_click_through_rate {
     sql_table_name: `mobile_measurement.marts.mart_click_through_rate` ;;

     dimension: grain { type: string }
     dimension: partner { type: string }
     dimension: platform { type: string }
     measure: avg_ctr {
       type: average
       sql: ${TABLE}.ctr_percentage ;;
     }
   }
   ```

3. **Build Dashboards**
   - Daily install trends by partner
   - CTR comparison across platforms
   - CPI optimization dashboard

## Troubleshooting

### Issue: "Permission Denied" when uploading to GCS

**Solution:**
- Verify service account has `Storage Object Admin` role
- Check `GOOGLE_APPLICATION_CREDENTIALS` points to correct key file
- Ensure bucket name matches `.env` configuration

### Issue: DBT fails with "Dataset not found"

**Solution:**
- Run `bq ls` to verify dataset exists
- Check `GCP_PROJECT_ID` and `BQ_DATASET` in `.env`
- Verify BigQuery API is enabled in GCP project

### Issue: External table shows no data

**Solution:**
- Run `gcloud storage ls gs://YOUR-BUCKET/raw/` to verify files exist
- Check external table definition matches GCS path
- Ensure JSONL format is correct (one JSON object per line)

### Issue: "Invalid JSON" errors in BigQuery

**Solution:**
- Validate generated JSONL file locally
- Run `python src/generator/event_generator.py --validate-only --output data/raw/file.jsonl`
- Check for special characters or encoding issues

## Testing

Run unit tests:

```bash
# Install pytest
pip install pytest pytest-cov

# Run tests
pytest tests/test_event_generator.py -v

# Run with coverage
pytest tests/test_event_generator.py --cov=src --cov-report=html
```

## Performance

**Generation:** 100 events generated in ~1 second
**Upload:** GCS upload typically < 5 seconds for 100 events
**DBT Run:** Full build completes in ~20-30 seconds
**Total Pipeline:** End-to-end execution in under 2 minutes

For larger datasets (1M+ events):
- Use batched generation with parallel uploads
- Partition BigQuery tables by date
- Enable incremental DBT models
- Consider BigQuery native tables instead of external

## Cost Estimation

**Monthly Costs (for 100 events, minimal usage):**

- **GCS Storage:** ~$0.01/month (< 1 MB data)
- **BigQuery Storage:** ~$0.02/month (active storage)
- **BigQuery Queries:** ~$0.01/month (< 10 MB scanned)
- **Total:** ~$0.04/month

For production scale (1M events/day):
- **GCS Storage:** ~$0.50/month
- **BigQuery Storage:** ~$10/month
- **BigQuery Queries:** ~$50/month (depending on query patterns)
- **Total:** ~$60/month

## Security Best Practices

1. **Never commit service account keys** to version control
2. **Use `.gitignore`** to exclude `.env` and `*.json` files
3. **Rotate service account keys** regularly (90 days)
4. **Use least-privilege IAM roles** (avoid Owner role)
5. **Enable GCS versioning** for data recovery
6. **Set up audit logging** for compliance

## License

This project is provided as-is for demonstration and educational purposes.

## Support

For issues or questions:
- Review troubleshooting section above
- Check [setup/setup_instructions.md](setup/setup_instructions.md) for detailed setup
- Review GCP documentation for service-specific issues

---

**Project Status:** Production-ready demo pipeline

**Last Updated:** 2026-02-12

**Version:** 1.0.0
