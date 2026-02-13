# Manual GCP Setup Instructions

If you prefer to set up GCP resources manually through the console, follow these steps.

## Prerequisites

- Google Cloud Platform account
- GCP project with billing enabled
- Basic familiarity with GCP console

## Step 1: Create GCS Bucket

1. Navigate to **Cloud Storage** in the GCP Console
2. Click **Create Bucket**
3. Configure bucket:
   - **Name**: `mobile-measurement-data` (or your preferred name)
   - **Location type**: Region
   - **Location**: `us-central1` (or your preferred region)
   - **Access control**: Uniform (recommended)
4. Click **Create**
5. In bucket details, go to **Configuration** tab
   - Enable **Object Versioning** (recommended for safety)

## Step 2: Create BigQuery Dataset

1. Navigate to **BigQuery** in the GCP Console
2. In the Explorer panel, click on your project ID
3. Click the three dots (**⋮**) next to your project
4. Select **Create dataset**
5. Configure dataset:
   - **Dataset ID**: `mobile_measurement`
   - **Data location**: `US` (or match your bucket region)
   - **Description**: "Mobile Measurement Data Pipeline"
6. Click **Create dataset**

## Step 3: Create Service Account

1. Navigate to **IAM & Admin** > **Service Accounts**
2. Click **Create Service Account**
3. Configure service account:
   - **Service account name**: `mobile-measurement-sa`
   - **Service account ID**: Will auto-generate
   - **Description**: "Service account for mobile measurement data pipeline"
4. Click **Create and Continue**

## Step 4: Grant IAM Roles

In the "Grant this service account access to project" section, add the following roles:

1. **Storage Object Admin**
   - Click "Add Another Role"
   - Search for: `Storage Object Admin`
   - Select and add

2. **BigQuery Data Editor**
   - Click "Add Another Role"
   - Search for: `BigQuery Data Editor`
   - Select and add

3. **BigQuery Job User**
   - Click "Add Another Role"
   - Search for: `BigQuery Job User`
   - Select and add

4. Click **Continue**, then **Done**

## Step 5: Create and Download Service Account Key

1. In the Service Accounts list, find your newly created service account
2. Click on the service account email
3. Go to the **Keys** tab
4. Click **Add Key** > **Create new key**
5. Select **JSON** format
6. Click **Create**
7. The key file will download automatically
8. **IMPORTANT**: Save this file securely as `service-account-key.json` in your project directory
   - DO NOT commit this file to version control
   - Keep it in a secure location

## Step 6: Configure Environment Variables

Create a `.env` file in your project root directory:

```bash
# GCP Configuration
GCP_PROJECT_ID=your-actual-project-id
GCS_BUCKET=mobile-measurement-data
BQ_DATASET=mobile_measurement
GCP_REGION=us-central1

# Authentication
GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\service-account-key.json
```

**Replace:**
- `your-actual-project-id` with your GCP project ID
- `C:\path\to\service-account-key.json` with the actual path to your key file

## Step 7: Verify Setup

Run the following commands to verify your setup:

### Check GCS Bucket
```bash
gcloud storage ls gs://mobile-measurement-data
```

### Check BigQuery Dataset
```bash
bq ls mobile_measurement
```

### Check Service Account
```bash
gcloud iam service-accounts list --filter="email:mobile-measurement-sa@*"
```

## Step 8: Install Dependencies

```bash
# Install Python packages
pip install -r requirements.txt

# Install DBT
pip install dbt-bigquery==1.7.0
```

## Troubleshooting

### Permission Denied Errors

If you encounter permission errors:
1. Verify service account has all required roles
2. Check that `GOOGLE_APPLICATION_CREDENTIALS` points to correct key file
3. Ensure you're using the correct GCP project ID

### Bucket Already Exists Error

If the bucket name is taken globally:
1. Use a unique bucket name (e.g., `mobile-measurement-data-your-org-name`)
2. Update the `GCS_BUCKET` variable in your `.env` file

### BigQuery Dataset Region Mismatch

If you get region mismatch errors:
1. Ensure GCS bucket and BigQuery dataset are in the same region
2. Update `GCP_REGION` in `.env` to match

## Next Steps

Once setup is complete, proceed to:

1. **Generate synthetic data:**
   ```bash
   python src/generator/event_generator.py --num-events 100 --bucket mobile-measurement-data
   ```

2. **Create BigQuery external table:**
   ```bash
   bq mk --external_table_definition=@NEWLINE_DELIMITED_JSON=gs://mobile-measurement-data/raw/*.jsonl mobile_measurement.mmp_events_external
   ```

3. **Run DBT transformations:**
   ```bash
   cd dbt_project
   dbt build
   ```

See the main README for detailed execution instructions.
