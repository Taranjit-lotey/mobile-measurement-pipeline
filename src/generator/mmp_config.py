"""Mobile Measurement Partner (MMP) configuration and constants"""
from typing import Dict, Tuple, List

# Event type probabilities (realistic MMP funnel)
# These represent a typical mobile advertising funnel
EVENT_PROBABILITIES = {
    'impression': 0.60,  # 60% - Top of funnel, highest volume
    'click': 0.25,       # 25% - ~2-5% CTR from impressions
    'install': 0.12,     # 12% - Install rate from clicks
    'reinstall': 0.03    # 3% - Small percentage of returning users
}

# Mobile Measurement Partner distribution (based on market share)
PARTNERS = ['Adjust', 'AppsFlyer', 'Branch', 'Kochava', 'Singular']
PARTNER_WEIGHTS = [0.30, 0.35, 0.20, 0.10, 0.05]

# Cost model - varies significantly by event type
# Format: (min_cost, max_cost) in USD
COST_RANGES: Dict[str, Tuple[float, float]] = {
    'impression': (0.001, 0.01),   # $0.001 - $0.01 per impression (CPM model)
    'click': (0.10, 0.50),          # $0.10 - $0.50 per click (CPC model)
    'install': (1.50, 8.00),        # $1.50 - $8.00 per install (CPI model)
    'reinstall': (0.80, 4.00)       # $0.80 - $4.00 per reinstall (lower than install)
}

# Platform distribution (mobile OS market share)
PLATFORMS = ['iOS', 'Android']
PLATFORM_WEIGHTS = [0.40, 0.60]  # Android slightly higher volume

# Sample app configurations
SAMPLE_APPS = [
    'com.example.game',
    'com.example.fitness',
    'com.example.social',
    'com.example.ecommerce',
    'com.example.productivity'
]

# Sample campaign IDs
SAMPLE_CAMPAIGNS = [
    'campaign_001_summer',
    'campaign_002_winter',
    'campaign_003_holiday',
    'campaign_004_launch',
    'campaign_005_retargeting',
    'campaign_006_brand',
    'campaign_007_performance',
    'campaign_008_test'
]

# Country codes (top mobile markets)
COUNTRY_CODES = ['US', 'CN', 'IN', 'BR', 'JP', 'DE', 'GB', 'FR', 'KR', 'CA']
COUNTRY_WEIGHTS = [0.25, 0.15, 0.12, 0.10, 0.08, 0.07, 0.06, 0.05, 0.05, 0.07]


def get_event_type_list() -> List[str]:
    """Get list of valid event types"""
    return list(EVENT_PROBABILITIES.keys())


def get_partner_list() -> List[str]:
    """Get list of MMP partners"""
    return PARTNERS


def get_platform_list() -> List[str]:
    """Get list of platforms"""
    return PLATFORMS
