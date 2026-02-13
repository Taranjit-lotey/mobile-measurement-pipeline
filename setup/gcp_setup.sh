#!/bin/bash
# GCP Resource Setup for Mobile Measurement Pipeline (Linux/Mac)
# This script creates all necessary GCP resources

set -e  # Exit on error

echo "============================================================"
echo "GCP SETUP - Mobile Measurement Data Pipeline"
echo "============================================================"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI not found. Please install it first."
    echo "Download from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Configuration (override with environment variables if set)
: ${GCP_PROJECT_ID:?'ERROR: GCP_PROJECT_ID environment variable not set'}
: ${GCS_BUCKET:=mobile-measurement-data}
: ${BQ_DATASET:=mobile_measurement}
: ${GCP_REGION:=us-central1}
: ${SERVICE_ACCOUNT_NAME:=mobile-measurement-sa}

echo ""
echo "Configuration:"
echo "  Project ID: $GCP_PROJECT_ID"
echo "  Bucket Name: $GCS_BUCKET"
echo "  BigQuery Dataset: $BQ_DATASET"
echo "  Region: $GCP_REGION"
echo "  Service Account: $SERVICE_ACCOUNT_NAME"
echo ""

read -p "Continue with setup? (Y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "[1/6] Setting active project..."
gcloud config set project $GCP_PROJECT_ID

echo ""
echo "[2/6] Creating GCS bucket: $GCS_BUCKET"
if gcloud storage buckets create gs://$GCS_BUCKET \
    --location=$GCP_REGION \
    --uniform-bucket-level-access; then
    echo "✓ Bucket created successfully"
else
    echo "⚠ Bucket creation failed (may already exist)"
fi

# Enable versioning
echo "  Enabling versioning..."
gcloud storage buckets update gs://$GCS_BUCKET --versioning

echo ""
echo "[3/6] Creating BigQuery dataset: $BQ_DATASET"
if bq mk \
    --dataset \
    --location=$GCP_REGION \
    --description="Mobile Measurement Data Pipeline" \
    $GCP_PROJECT_ID:$BQ_DATASET; then
    echo "✓ Dataset created successfully"
else
    echo "⚠ Dataset creation failed (may already exist)"
fi

echo ""
echo "[4/6] Creating service account: $SERVICE_ACCOUNT_NAME"
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"

if gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Mobile Measurement Pipeline Service Account" \
    --description="Service account for mobile measurement data pipeline"; then
    echo "✓ Service account created successfully"
else
    echo "⚠ Service account creation failed (may already exist)"
fi

echo ""
echo "[5/6] Granting IAM roles to service account..."

# Storage Object Admin (for GCS read/write)
echo "  - Storage Object Admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.objectAdmin" \
    --quiet

# BigQuery Data Editor (for table creation/modification)
echo "  - BigQuery Data Editor"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.dataEditor" \
    --quiet

# BigQuery Job User (for running queries)
echo "  - BigQuery Job User"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.jobUser" \
    --quiet

echo ""
echo "[6/6] Creating and downloading service account key..."
KEY_FILE="service-account-key.json"
gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SERVICE_ACCOUNT_EMAIL

echo ""
echo "============================================================"
echo "SETUP COMPLETE!"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Create .env file in project root with:"
echo "   GCP_PROJECT_ID=$GCP_PROJECT_ID"
echo "   GCS_BUCKET=$GCS_BUCKET"
echo "   BQ_DATASET=$BQ_DATASET"
echo "   GCP_REGION=$GCP_REGION"
echo "   GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/$KEY_FILE"
echo ""
echo "2. Install Python dependencies:"
echo "   pip install -r requirements.txt"
echo "   pip install dbt-bigquery==1.7.0"
echo ""
echo "3. Generate and upload events:"
echo "   python src/generator/event_generator.py --num-events 100 --bucket $GCS_BUCKET"
echo ""
echo "Service account key saved: $KEY_FILE"
echo "⚠ WARNING: Keep this file secure and do not commit to version control!"
echo ""
