"""
Mobile Measurement Partner (MMP) Event Generator

Generates synthetic mobile measurement events for testing and demonstration purposes.
Events are generated with realistic distributions and uploaded to Google Cloud Storage.
"""
import json
import random
import uuid
import os
import sys
from datetime import datetime, timedelta
from typing import List, Dict, Any
import click

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from src.generator import mmp_config
from src.utils.gcs_uploader import GCSUploader
from src.utils.validation import MMPEventValidator
from src.config import config


def generate_event(historical_days: int = 30) -> Dict[str, Any]:
    """
    Generate a single synthetic MMP event with realistic distributions

    Args:
        historical_days: Generate timestamp within past N days

    Returns:
        Dictionary containing event data
    """
    # Randomly select event type based on probabilities
    event_type = random.choices(
        list(mmp_config.EVENT_PROBABILITIES.keys()),
        weights=list(mmp_config.EVENT_PROBABILITIES.values()),
        k=1
    )[0]

    # Select partner based on market share weights
    partner = random.choices(
        mmp_config.PARTNERS,
        weights=mmp_config.PARTNER_WEIGHTS,
        k=1
    )[0]

    # Select platform
    platform = random.choices(
        mmp_config.PLATFORMS,
        weights=mmp_config.PLATFORM_WEIGHTS,
        k=1
    )[0]

    # Select country
    country = random.choices(
        mmp_config.COUNTRY_CODES,
        weights=mmp_config.COUNTRY_WEIGHTS,
        k=1
    )[0]

    # Generate cost based on event type
    cost_min, cost_max = mmp_config.COST_RANGES[event_type]
    cost_usd = round(random.uniform(cost_min, cost_max), 2)

    # Generate timestamp (random time within past N days)
    now = datetime.utcnow()
    random_seconds = random.randint(0, historical_days * 24 * 60 * 60)
    event_time = now - timedelta(seconds=random_seconds)
    timestamp = event_time.strftime('%Y-%m-%dT%H:%M:%SZ')

    # Create event
    event = {
        'event_id': str(uuid.uuid4()),
        'timestamp': timestamp,
        'event_type': event_type,
        'partner': partner,
        'cost_usd': cost_usd,
        'app_id': random.choice(mmp_config.SAMPLE_APPS),
        'campaign_id': random.choice(mmp_config.SAMPLE_CAMPAIGNS),
        'platform': platform,
        'country_code': country
    }

    return event


def generate_batch(num_events: int, historical_days: int = 30) -> List[Dict[str, Any]]:
    """
    Generate a batch of MMP events

    Args:
        num_events: Number of events to generate
        historical_days: Generate timestamps within past N days

    Returns:
        List of event dictionaries
    """
    events = []

    print(f"Generating {num_events} mobile measurement events...")

    for i in range(num_events):
        event = generate_event(historical_days)
        events.append(event)

        # Progress indicator
        if (i + 1) % 10 == 0 or (i + 1) == num_events:
            print(f"  Progress: {i + 1}/{num_events} events generated")

    return events


def save_local_backup(events: List[Dict[str, Any]], output_file: str) -> None:
    """
    Save events to local file as backup

    Args:
        events: List of event dictionaries
        output_file: Path to output file
    """
    # Ensure directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    # Write as JSONL
    with open(output_file, 'w') as f:
        for event in events:
            f.write(json.dumps(event) + '\n')

    print(f"✓ Local backup saved: {output_file}")


def print_event_summary(events: List[Dict[str, Any]]) -> None:
    """Print summary statistics of generated events"""
    distribution = MMPEventValidator.get_event_distribution(events)
    total_cost = MMPEventValidator.calculate_total_cost(events)

    print("\n" + "="*60)
    print("EVENT GENERATION SUMMARY")
    print("="*60)

    print(f"\nTotal Events: {len(events)}")

    print("\nEvent Type Distribution:")
    for event_type in sorted(distribution.keys()):
        count = distribution[event_type]
        percentage = (count / len(events)) * 100
        print(f"  {event_type:12s}: {count:3d} events ({percentage:5.1f}%)")

    print(f"\nTotal Cost: ${total_cost:,.2f}")
    print(f"Average Cost per Event: ${total_cost/len(events):.2f}")

    # Partner distribution
    partner_dist = {}
    for event in events:
        partner = event['partner']
        partner_dist[partner] = partner_dist.get(partner, 0) + 1

    print("\nPartner Distribution:")
    for partner in sorted(partner_dist.keys()):
        count = partner_dist[partner]
        percentage = (count / len(events)) * 100
        print(f"  {partner:12s}: {count:3d} events ({percentage:5.1f}%)")

    # Platform distribution
    platform_dist = {}
    for event in events:
        platform = event['platform']
        platform_dist[platform] = platform_dist.get(platform, 0) + 1

    print("\nPlatform Distribution:")
    for platform in sorted(platform_dist.keys()):
        count = platform_dist[platform]
        percentage = (count / len(events)) * 100
        print(f"  {platform:12s}: {count:3d} events ({percentage:5.1f}%)")

    print("="*60 + "\n")


@click.command()
@click.option(
    '--num-events',
    default=100,
    type=int,
    help='Number of events to generate (default: 100)'
)
@click.option(
    '--bucket',
    default=None,
    type=str,
    help='GCS bucket name (overrides .env config)'
)
@click.option(
    '--local-only',
    is_flag=True,
    help='Generate events locally without uploading to GCS'
)
@click.option(
    '--output',
    default='data/raw/mmp_events.jsonl',
    type=str,
    help='Local output file path (default: data/raw/mmp_events.jsonl)'
)
@click.option(
    '--historical-days',
    default=30,
    type=int,
    help='Spread events over past N days (default: 30)'
)
@click.option(
    '--validate-only',
    is_flag=True,
    help='Validate existing file specified by --output'
)
def main(num_events, bucket, local_only, output, historical_days, validate_only):
    """
    Generate synthetic mobile measurement partner (MMP) events

    Examples:

      # Generate 100 events and upload to GCS
      python event_generator.py --num-events 100 --bucket mobile-measurement-data

      # Generate events locally only (no GCS upload)
      python event_generator.py --num-events 100 --local-only

      # Validate existing file
      python event_generator.py --validate-only --output data/raw/mmp_events.jsonl
    """

    # Validate-only mode
    if validate_only:
        print(f"Validating events from: {output}")

        if not os.path.exists(output):
            print(f"Error: File not found: {output}")
            sys.exit(1)

        # Read events from file
        events = []
        with open(output, 'r') as f:
            for line in f:
                events.append(json.loads(line.strip()))

        # Validate
        valid, invalid, errors = MMPEventValidator.validate_batch(events)

        if invalid > 0:
            print(f"\n✗ Validation failed: {invalid} invalid events")
            for error in errors[:10]:  # Show first 10 errors
                print(f"  {error}")
            sys.exit(1)
        else:
            print(f"✓ All {valid} events are valid")
            print_event_summary(events)
            sys.exit(0)

    # Generation mode
    print("\n" + "="*60)
    print("MOBILE MEASUREMENT EVENT GENERATOR")
    print("="*60 + "\n")

    # Generate events
    events = generate_batch(num_events, historical_days)

    # Validate events
    print("\nValidating generated events...")
    valid, invalid, errors = MMPEventValidator.validate_batch(events)

    if invalid > 0:
        print(f"\n✗ Validation failed: {invalid} invalid events")
        for error in errors:
            print(f"  {error}")
        sys.exit(1)

    print(f"✓ All {valid} events validated successfully")

    # Print summary
    print_event_summary(events)

    # Save local backup
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    output_with_timestamp = output.replace('.jsonl', f'_{timestamp}.jsonl')
    save_local_backup(events, output_with_timestamp)

    # Upload to GCS (unless local-only mode)
    if not local_only:
        bucket_name = bucket or config.bucket_name

        if not bucket_name:
            print("\n✗ Error: GCS bucket not specified")
            print("  Either use --bucket option or set GCS_BUCKET in .env file")
            sys.exit(1)

        print(f"\nUploading to GCS bucket: {bucket_name}")

        try:
            uploader = GCSUploader(bucket_name)
            blob_name = f"raw/mmp_events_{timestamp}.jsonl"
            gcs_uri = uploader.upload_json_lines(events, blob_name)

            # Get file size
            file_size = uploader.get_blob_size(blob_name)
            file_size_kb = file_size / 1024

            print(f"✓ Upload complete!")
            print(f"  GCS URI: {gcs_uri}")
            print(f"  File size: {file_size_kb:.1f} KB")
            print(f"  Event count: {len(events)}")

        except Exception as e:
            print(f"\n✗ Upload failed: {e}")
            print(f"  Events saved locally: {output_with_timestamp}")
            sys.exit(1)

    print("\n✓ Event generation complete!\n")


if __name__ == '__main__':
    main()
