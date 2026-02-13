"""Data validation utilities for MMP events"""
from typing import Dict, Any, List, Tuple
from datetime import datetime


class MMPEventValidator:
    """Validate mobile measurement partner event data"""

    REQUIRED_FIELDS = [
        'event_id',
        'timestamp',
        'event_type',
        'partner',
        'cost_usd',
        'app_id',
        'campaign_id',
        'platform',
        'country_code'
    ]

    VALID_EVENT_TYPES = ['install', 'reinstall', 'click', 'impression']
    VALID_PLATFORMS = ['iOS', 'Android']

    @staticmethod
    def validate_event(event: Dict[str, Any]) -> Tuple[bool, List[str]]:
        """
        Validate a single event

        Args:
            event: Event dictionary to validate

        Returns:
            Tuple of (is_valid, list of error messages)
        """
        errors = []

        # Check required fields
        for field in MMPEventValidator.REQUIRED_FIELDS:
            if field not in event:
                errors.append(f"Missing required field: {field}")

        if errors:
            return False, errors

        # Validate event_type
        if event['event_type'] not in MMPEventValidator.VALID_EVENT_TYPES:
            errors.append(
                f"Invalid event_type: {event['event_type']}. "
                f"Must be one of {MMPEventValidator.VALID_EVENT_TYPES}"
            )

        # Validate platform
        if event['platform'] not in MMPEventValidator.VALID_PLATFORMS:
            errors.append(
                f"Invalid platform: {event['platform']}. "
                f"Must be one of {MMPEventValidator.VALID_PLATFORMS}"
            )

        # Validate cost (must be non-negative)
        try:
            cost = float(event['cost_usd'])
            if cost < 0:
                errors.append(f"Cost must be non-negative: {cost}")
        except (ValueError, TypeError):
            errors.append(f"Invalid cost_usd value: {event['cost_usd']}")

        # Validate timestamp format (ISO 8601)
        try:
            datetime.fromisoformat(event['timestamp'].replace('Z', '+00:00'))
        except (ValueError, AttributeError):
            errors.append(f"Invalid timestamp format: {event['timestamp']}")

        # Validate event_id (non-empty string)
        if not isinstance(event['event_id'], str) or not event['event_id']:
            errors.append("event_id must be a non-empty string")

        return len(errors) == 0, errors

    @staticmethod
    def validate_batch(events: List[Dict[str, Any]]) -> Tuple[int, int, List[str]]:
        """
        Validate a batch of events

        Args:
            events: List of event dictionaries

        Returns:
            Tuple of (valid_count, invalid_count, list of error summaries)
        """
        valid_count = 0
        invalid_count = 0
        error_summaries = []

        for idx, event in enumerate(events):
            is_valid, errors = MMPEventValidator.validate_event(event)
            if is_valid:
                valid_count += 1
            else:
                invalid_count += 1
                error_summaries.append(f"Event {idx}: {'; '.join(errors)}")

        return valid_count, invalid_count, error_summaries

    @staticmethod
    def get_event_distribution(events: List[Dict[str, Any]]) -> Dict[str, int]:
        """Get distribution of event types"""
        distribution = {}
        for event in events:
            event_type = event.get('event_type', 'unknown')
            distribution[event_type] = distribution.get(event_type, 0) + 1
        return distribution

    @staticmethod
    def calculate_total_cost(events: List[Dict[str, Any]]) -> float:
        """Calculate total cost across all events"""
        return sum(float(event.get('cost_usd', 0)) for event in events)
