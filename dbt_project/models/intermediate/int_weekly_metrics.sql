{{
    config(
        materialized='table',
        description='Weekly aggregated mobile measurement metrics by partner and platform (week starting Monday)'
    )
}}

SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start_date,
    partner,
    platform,

    -- Install metrics
    COUNTIF(event_type = 'install') AS installs,
    COUNTIF(event_type = 'reinstall') AS reinstalls,

    -- Click-through rate components
    COUNTIF(event_type = 'click') AS clicks,
    COUNTIF(event_type = 'impression') AS impressions,

    -- Cost metrics
    SUM(CASE WHEN event_type = 'install' THEN cost_usd ELSE 0 END) AS install_cost,
    SUM(CASE WHEN event_type = 'reinstall' THEN cost_usd ELSE 0 END) AS reinstall_cost,
    SUM(CASE WHEN event_type = 'click' THEN cost_usd ELSE 0 END) AS click_cost,
    SUM(CASE WHEN event_type = 'impression' THEN cost_usd ELSE 0 END) AS impression_cost,
    SUM(cost_usd) AS total_cost,

    -- Event counts for data quality checks
    COUNT(*) AS total_events,

    -- Metadata
    CURRENT_TIMESTAMP() AS dbt_updated_at

FROM {{ ref('stg_mmp_events') }}

GROUP BY
    week_start_date,
    partner,
    platform

ORDER BY
    week_start_date DESC,
    partner,
    platform
