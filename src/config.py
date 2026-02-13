"""Centralized configuration management for GCP resources"""
import os
from dataclasses import dataclass
from typing import Optional
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


@dataclass
class GCPConfig:
    """Google Cloud Platform configuration"""

    project_id: str = os.getenv('GCP_PROJECT_ID', '')
    bucket_name: str = os.getenv('GCS_BUCKET', 'mobile-measurement-data')
    dataset_id: str = os.getenv('BQ_DATASET', 'mobile_measurement')
    region: str = os.getenv('GCP_REGION', 'us-central1')
    service_account_path: Optional[str] = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')

    def __post_init__(self):
        """Validate configuration after initialization"""
        if not self.project_id:
            print("Warning: GCP_PROJECT_ID not set in environment variables")

        if self.service_account_path and not os.path.exists(self.service_account_path):
            print(f"Warning: Service account key file not found at {self.service_account_path}")

    def get_bucket_uri(self, path: str = "") -> str:
        """Get GCS bucket URI"""
        if path:
            return f"gs://{self.bucket_name}/{path}"
        return f"gs://{self.bucket_name}"

    def get_table_id(self, table_name: str) -> str:
        """Get fully qualified BigQuery table ID"""
        return f"{self.project_id}.{self.dataset_id}.{table_name}"


# Singleton instance for easy import
config = GCPConfig()
