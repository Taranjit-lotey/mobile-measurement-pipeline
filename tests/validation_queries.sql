-- BigQuery Validation Queries for Mobile Measurement Pipeline
-- Run these queries to verify the pipeline is working correctly

-- ============================================================
-- Query 1: Record Count Check
-- ============================================================
-- Expected: 100 events (matching the generated data)
SELECT COUNT(*) as total_events
FROM `mobile_measurement.stg_mmp_events`;


-- ============================================================
-- Query 2: Event Distribution
-- ============================================================
-- Expected: ~60 impressions, ~25 clicks, ~12 installs, ~3 reinstalls
SELECT
    event_type,
    COUNT(*) as event_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) as percentage,
    ROUND(SUM(cost_usd), 2) as total_cost
FROM `mobile_measurement.stg_mmp_events`
GROUP BY event_type
ORDER BY event_count DESC;


-- ============================================================
-- Query 3: Partner Distribution
-- ============================================================
-- Expected: AppsFlyer ~35%, Adjust ~30%, Branch ~20%, Kochava ~10%, Singular ~5%
SELECT
    partner,
    COUNT(*) as event_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) as percentage
FROM `mobile_measurement.stg_mmp_events`
GROUP BY partner
ORDER BY event_count DESC;


-- ============================================================
-- Query 4: Daily Metrics Summary
-- ============================================================
-- Check aggregated daily metrics
SELECT
    event_date,
    partner,
    platform,
    installs,
    clicks,
    impressions,
    ROUND(clicks / impressions * 100, 2) as ctr_pct,
    ROUND(total_cost, 2) as total_cost
FROM `mobile_measurement.int_daily_metrics`
ORDER BY event_date DESC, partner
LIMIT 20;


-- ============================================================
-- Query 5: CTR Validation
-- ============================================================
-- Expected: CTR between 2-5% (realistic for mobile ads)
SELECT
    grain,
    partner,
    ROUND(AVG(ctr_percentage), 2) as avg_ctr_pct,
    ROUND(MIN(ctr_percentage), 2) as min_ctr_pct,
    ROUND(MAX(ctr_percentage), 2) as max_ctr_pct,
    COUNT(*) as record_count
FROM `mobile_measurement.mart_click_through_rate`
GROUP BY grain, partner
ORDER BY grain, avg_ctr_pct DESC;


-- ============================================================
-- Query 6: CPI Validation
-- ============================================================
-- Expected: CPI between $1.50-$8.00
SELECT
    grain,
    platform,
    ROUND(AVG(cpi_direct_rounded), 2) as avg_cpi,
    ROUND(MIN(cpi_direct_rounded), 2) as min_cpi,
    ROUND(MAX(cpi_direct_rounded), 2) as max_cpi,
    COUNT(*) as record_count
FROM `mobile_measurement.mart_cost_per_install`
GROUP BY grain, platform
ORDER BY grain, avg_cpi;


-- ============================================================
-- Query 7: Grain Coverage Check
-- ============================================================
-- Expected: Records for 'daily', 'weekly', 'monthly' in all marts
SELECT
    'installs_reinstalls' as mart_name,
    grain,
    COUNT(*) as record_count
FROM `mobile_measurement.mart_installs_reinstalls`
GROUP BY grain

UNION ALL

SELECT
    'click_through_rate' as mart_name,
    grain,
    COUNT(*) as record_count
FROM `mobile_measurement.mart_click_through_rate`
GROUP BY grain

UNION ALL

SELECT
    'cost_per_install' as mart_name,
    grain,
    COUNT(*) as record_count
FROM `mobile_measurement.mart_cost_per_install`
GROUP BY grain

ORDER BY mart_name, grain;


-- ============================================================
-- Query 8: Install Volume by Partner and Platform
-- ============================================================
-- Business insight: Which partner/platform combinations drive most installs?
SELECT
    partner,
    platform,
    SUM(installs) as total_installs,
    SUM(reinstalls) as total_reinstalls,
    ROUND(SUM(total_install_cost), 2) as total_cost
FROM `mobile_measurement.mart_installs_reinstalls`
WHERE grain = 'monthly'  -- Monthly aggregation for overview
GROUP BY partner, platform
ORDER BY total_installs DESC;


-- ============================================================
-- Query 9: Cost Efficiency Analysis
-- ============================================================
-- Business insight: Which partner offers best CPI?
SELECT
    partner,
    ROUND(AVG(cpi_direct_rounded), 2) as avg_cpi,
    SUM(installs) as total_installs,
    ROUND(SUM(install_cost), 2) as total_spend
FROM `mobile_measurement.mart_cost_per_install`
WHERE grain = 'daily'
GROUP BY partner
ORDER BY avg_cpi ASC;


-- ============================================================
-- Query 10: Time Series Trend
-- ============================================================
-- Business insight: Install volume over time
SELECT
    period,
    SUM(installs) as total_installs,
    SUM(clicks) as total_clicks,
    SUM(impressions) as total_impressions
FROM `mobile_measurement.mart_installs_reinstalls`
WHERE grain = 'daily'
GROUP BY period
ORDER BY period DESC
LIMIT 30;


-- ============================================================
-- Query 11: Data Quality Check - Missing Values
-- ============================================================
-- Ensure no critical nulls in staging layer
SELECT
    COUNTIF(event_id IS NULL) as null_event_id,
    COUNTIF(event_timestamp IS NULL) as null_timestamp,
    COUNTIF(event_type IS NULL) as null_event_type,
    COUNTIF(partner IS NULL) as null_partner,
    COUNTIF(cost_usd IS NULL) as null_cost,
    COUNT(*) as total_records
FROM `mobile_measurement.stg_mmp_events`;


-- ============================================================
-- Query 12: Cost Distribution by Event Type
-- ============================================================
-- Business insight: Where is marketing budget being spent?
SELECT
    event_type,
    COUNT(*) as event_count,
    ROUND(SUM(cost_usd), 2) as total_cost,
    ROUND(AVG(cost_usd), 4) as avg_cost_per_event,
    ROUND(SUM(cost_usd) * 100.0 / SUM(SUM(cost_usd)) OVER(), 1) as cost_percentage
FROM `mobile_measurement.stg_mmp_events`
GROUP BY event_type
ORDER BY total_cost DESC;
