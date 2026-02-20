-- BigQuery Validation Queries for Mobile Measurement Pipeline
-- Run these queries to verify the pipeline is working correctly

-- ============================================================
-- Query 1: Record Count Check
-- ============================================================
-- Expected: 100 events (matching the generated data)
SELECT COUNT(*) as total_events
FROM `mobile_measurement.stg_mmp_events`;

