@echo off
REM GCP Resource Setup for Mobile Measurement Pipeline (Windows)
REM This script creates all necessary GCP resources

echo ============================================================
echo GCP SETUP - Mobile Measurement Data Pipeline
echo ============================================================
echo.

REM Check if gcloud is installed
where gcloud >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: gcloud CLI not found. Please install it first.
    echo Download from: https://cloud.google.com/sdk/docs/install
    exit /b 1
)

REM Configuration (override with environment variables if set)
if "%GCP_PROJECT_ID%"=="" (
    set /p GCP_PROJECT_ID="Enter GCP Project ID: "
)
if "%GCS_BUCKET%"=="" set GCS_BUCKET=mobile-measurement-data
if "%BQ_DATASET%"=="" set BQ_DATASET=mobile_measurement
if "%GCP_REGION%"=="" set GCP_REGION=us-central1
if "%SERVICE_ACCOUNT_NAME%"=="" set SERVICE_ACCOUNT_NAME=mobile-measurement-sa

echo.
echo Configuration:
echo   Project ID: %GCP_PROJECT_ID%
echo   Bucket Name: %GCS_BUCKET%
echo   BigQuery Dataset: %BQ_DATASET%
echo   Region: %GCP_REGION%
echo   Service Account: %SERVICE_ACCOUNT_NAME%
echo.

set /p CONFIRM="Continue with setup? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Setup cancelled.
    exit /b 0
)

echo.
echo [1/6] Setting active project...
gcloud config set project %GCP_PROJECT_ID%
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to set project
    exit /b 1
)

echo.
echo [2/6] Creating GCS bucket: %GCS_BUCKET%
gcloud storage buckets create gs://%GCS_BUCKET% --location=%GCP_REGION% --uniform-bucket-level-access
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Bucket creation failed (may already exist)
)

REM Enable versioning
echo   Enabling versioning...
gcloud storage buckets update gs://%GCS_BUCKET% --versioning

echo.
echo [3/6] Creating BigQuery dataset: %BQ_DATASET%
bq mk --dataset --location=%GCP_REGION% --description="Mobile Measurement Data Pipeline" %GCP_PROJECT_ID%:%BQ_DATASET%
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Dataset creation failed (may already exist)
)

echo.
echo [4/6] Creating service account: %SERVICE_ACCOUNT_NAME%
gcloud iam service-accounts create %SERVICE_ACCOUNT_NAME% ^
    --display-name="Mobile Measurement Pipeline Service Account" ^
    --description="Service account for mobile measurement data pipeline"
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Service account creation failed (may already exist)
)

set SERVICE_ACCOUNT_EMAIL=%SERVICE_ACCOUNT_NAME%@%GCP_PROJECT_ID%.iam.gserviceaccount.com

echo.
echo [5/6] Granting IAM roles to service account...

REM Storage Object Admin (for GCS read/write)
echo   - Storage Object Admin
gcloud projects add-iam-policy-binding %GCP_PROJECT_ID% ^
    --member="serviceAccount:%SERVICE_ACCOUNT_EMAIL%" ^
    --role="roles/storage.objectAdmin" ^
    --quiet

REM BigQuery Data Editor (for table creation/modification)
echo   - BigQuery Data Editor
gcloud projects add-iam-policy-binding %GCP_PROJECT_ID% ^
    --member="serviceAccount:%SERVICE_ACCOUNT_EMAIL%" ^
    --role="roles/bigquery.dataEditor" ^
    --quiet

REM BigQuery Job User (for running queries)
echo   - BigQuery Job User
gcloud projects add-iam-policy-binding %GCP_PROJECT_ID% ^
    --member="serviceAccount:%SERVICE_ACCOUNT_EMAIL%" ^
    --role="roles/bigquery.jobUser" ^
    --quiet

echo.
echo [6/6] Creating and downloading service account key...
set KEY_FILE=service-account-key.json
gcloud iam service-accounts keys create %KEY_FILE% ^
    --iam-account=%SERVICE_ACCOUNT_EMAIL%
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to create service account key
    exit /b 1
)

echo.
echo ============================================================
echo SETUP COMPLETE!
echo ============================================================
echo.
echo Next steps:
echo.
echo 1. Create .env file in project root with:
echo    GCP_PROJECT_ID=%GCP_PROJECT_ID%
echo    GCS_BUCKET=%GCS_BUCKET%
echo    BQ_DATASET=%BQ_DATASET%
echo    GCP_REGION=%GCP_REGION%
echo    GOOGLE_APPLICATION_CREDENTIALS=%cd%\%KEY_FILE%
echo.
echo 2. Install Python dependencies:
echo    pip install -r requirements.txt
echo    pip install dbt-bigquery==1.7.0
echo.
echo 3. Generate and upload events:
echo    python src\generator\event_generator.py --num-events 100 --bucket %GCS_BUCKET%
echo.
echo Service account key saved: %KEY_FILE%
echo WARNING: Keep this file secure and do not commit to version control!
echo.

pause
