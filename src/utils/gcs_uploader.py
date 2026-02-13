"""Google Cloud Storage upload utilities with retry logic"""
import json
import time
from typing import List, Dict, Any
from google.cloud import storage
from google.api_core import retry
from google.api_core import exceptions


class GCSUploader:
    """Upload data to Google Cloud Storage with error handling"""

    def __init__(self, bucket_name: str):
        """Initialize GCS client and bucket"""
        self.client = storage.Client()
        self.bucket_name = bucket_name
        self.bucket = self.client.bucket(bucket_name)

    def upload_json_lines(
        self,
        events: List[Dict[str, Any]],
        blob_name: str,
        max_retries: int = 3
    ) -> str:
        """
        Upload events as newline-delimited JSON (JSONL) to GCS

        Args:
            events: List of event dictionaries
            blob_name: Target blob name (path in bucket)
            max_retries: Maximum number of upload retries

        Returns:
            GCS URI of uploaded file
        """
        # Convert events to JSONL format
        jsonl_content = "\n".join([json.dumps(event) for event in events])

        # Create blob
        blob = self.bucket.blob(blob_name)

        # Upload with retry logic
        for attempt in range(max_retries):
            try:
                blob.upload_from_string(
                    jsonl_content,
                    content_type='application/jsonl'
                )
                gcs_uri = f"gs://{self.bucket_name}/{blob_name}"
                print(f"✓ Successfully uploaded to {gcs_uri}")
                return gcs_uri

            except exceptions.GoogleAPIError as e:
                if attempt < max_retries - 1:
                    wait_time = 2 ** attempt  # Exponential backoff
                    print(f"Upload failed (attempt {attempt + 1}/{max_retries}). Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    raise Exception(f"Failed to upload after {max_retries} attempts: {e}")

    def list_blobs(self, prefix: str = "") -> List[str]:
        """List all blobs in bucket with optional prefix"""
        blobs = self.client.list_blobs(self.bucket_name, prefix=prefix)
        return [blob.name for blob in blobs]

    def blob_exists(self, blob_name: str) -> bool:
        """Check if blob exists in bucket"""
        blob = self.bucket.blob(blob_name)
        return blob.exists()

    def get_blob_size(self, blob_name: str) -> int:
        """Get blob size in bytes"""
        blob = self.bucket.blob(blob_name)
        blob.reload()
        return blob.size
