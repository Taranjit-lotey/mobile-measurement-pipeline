"""Unit tests for MMP event generator"""
import pytest
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.generator.event_generator import generate_event, generate_batch
from src.generator import mmp_config
from src.utils.validation import MMPEventValidator


class TestEventGeneration:
    """Test event generation functionality"""

    def test_generate_single_event(self):
        """Test single event generation"""
        event = generate_event()

        # Check required fields exist
        assert 'event_id' in event
        assert 'timestamp' in event
        assert 'event_type' in event
        assert 'partner' in event
        assert 'cost_usd' in event
        assert 'app_id' in event
        assert 'campaign_id' in event
        assert 'platform' in event
        assert 'country_code' in event

    def test_event_type_validity(self):
        """Test that event_type is valid"""
        event = generate_event()
        assert event['event_type'] in mmp_config.get_event_type_list()

    def test_partner_validity(self):
        """Test that partner is valid"""
        event = generate_event()
        assert event['partner'] in mmp_config.get_partner_list()

    def test_platform_validity(self):
        """Test that platform is valid"""
        event = generate_event()
        assert event['platform'] in mmp_config.get_platform_list()

    def test_cost_is_positive(self):
        """Test that cost is non-negative"""
        event = generate_event()
        assert event['cost_usd'] >= 0

    def test_cost_ranges_by_event_type(self):
        """Test that costs fall within expected ranges for event types"""
        # Generate many events to test cost ranges
        events = [generate_event() for _ in range(100)]

        for event in events:
            event_type = event['event_type']
            cost = event['cost_usd']
            min_cost, max_cost = mmp_config.COST_RANGES[event_type]

            assert min_cost <= cost <= max_cost, \
                f"Cost {cost} for {event_type} outside range [{min_cost}, {max_cost}]"

    def test_event_type_distribution(self):
        """Test event type distribution over large sample"""
        events = [generate_event() for _ in range(1000)]

        distribution = {}
        for event in events:
            event_type = event['event_type']
            distribution[event_type] = distribution.get(event_type, 0) + 1

        # Check impressions (should be ~60%, allow 55-65%)
        impression_count = distribution.get('impression', 0)
        impression_pct = impression_count / 1000
        assert 0.55 <= impression_pct <= 0.65, \
            f"Impression percentage {impression_pct} outside expected range [0.55, 0.65]"

        # Check clicks (should be ~25%, allow 20-30%)
        click_count = distribution.get('click', 0)
        click_pct = click_count / 1000
        assert 0.20 <= click_pct <= 0.30, \
            f"Click percentage {click_pct} outside expected range [0.20, 0.30]"

    def test_batch_generation(self):
        """Test batch generation"""
        num_events = 50
        events = generate_batch(num_events)

        assert len(events) == num_events
        assert all(isinstance(e, dict) for e in events)

    def test_event_validation_pass(self):
        """Test that generated events pass validation"""
        event = generate_event()
        is_valid, errors = MMPEventValidator.validate_event(event)

        assert is_valid, f"Generated event failed validation: {errors}"
        assert len(errors) == 0

    def test_batch_validation_pass(self):
        """Test that batch of generated events pass validation"""
        events = generate_batch(20)
        valid, invalid, errors = MMPEventValidator.validate_batch(events)

        assert valid == 20
        assert invalid == 0
        assert len(errors) == 0


class TestEventValidator:
    """Test event validation functionality"""

    def test_validate_valid_event(self):
        """Test validation of a valid event"""
        event = {
            'event_id': 'test-123',
            'timestamp': '2026-02-12T14:30:00Z',
            'event_type': 'install',
            'partner': 'Adjust',
            'cost_usd': 5.50,
            'app_id': 'com.test.app',
            'campaign_id': 'campaign_001',
            'platform': 'iOS',
            'country_code': 'US'
        }

        is_valid, errors = MMPEventValidator.validate_event(event)
        assert is_valid
        assert len(errors) == 0

    def test_validate_missing_field(self):
        """Test validation fails for missing required field"""
        event = {
            'event_id': 'test-123',
            'timestamp': '2026-02-12T14:30:00Z',
            # Missing event_type
            'partner': 'Adjust',
            'cost_usd': 5.50,
            'app_id': 'com.test.app',
            'campaign_id': 'campaign_001',
            'platform': 'iOS',
            'country_code': 'US'
        }

        is_valid, errors = MMPEventValidator.validate_event(event)
        assert not is_valid
        assert len(errors) > 0

    def test_validate_invalid_event_type(self):
        """Test validation fails for invalid event_type"""
        event = {
            'event_id': 'test-123',
            'timestamp': '2026-02-12T14:30:00Z',
            'event_type': 'invalid_type',
            'partner': 'Adjust',
            'cost_usd': 5.50,
            'app_id': 'com.test.app',
            'campaign_id': 'campaign_001',
            'platform': 'iOS',
            'country_code': 'US'
        }

        is_valid, errors = MMPEventValidator.validate_event(event)
        assert not is_valid
        assert any('event_type' in error for error in errors)

    def test_validate_negative_cost(self):
        """Test validation fails for negative cost"""
        event = {
            'event_id': 'test-123',
            'timestamp': '2026-02-12T14:30:00Z',
            'event_type': 'install',
            'partner': 'Adjust',
            'cost_usd': -5.50,  # Negative cost
            'app_id': 'com.test.app',
            'campaign_id': 'campaign_001',
            'platform': 'iOS',
            'country_code': 'US'
        }

        is_valid, errors = MMPEventValidator.validate_event(event)
        assert not is_valid
        assert any('cost' in error.lower() for error in errors)

    def test_get_event_distribution(self):
        """Test event distribution calculation"""
        events = [
            {'event_type': 'install'},
            {'event_type': 'install'},
            {'event_type': 'click'},
            {'event_type': 'impression'}
        ]

        distribution = MMPEventValidator.get_event_distribution(events)

        assert distribution['install'] == 2
        assert distribution['click'] == 1
        assert distribution['impression'] == 1

    def test_calculate_total_cost(self):
        """Test total cost calculation"""
        events = [
            {'cost_usd': 5.50},
            {'cost_usd': 3.25},
            {'cost_usd': 1.00}
        ]

        total_cost = MMPEventValidator.calculate_total_cost(events)
        assert total_cost == 9.75


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
