{{
    config(
        materialized='table',
        description='Click-through rate (CTR) metrics aggregated across multiple time grains (daily/weekly/monthly)'
    )
}}

WITH daily AS (
    SELECT
        'daily' AS grain,
        CAST(event_date AS STRING) AS period,
        partner,
        platform,
        clicks,
        impressions,
        SAFE_DIVIDE(clicks, impressions) AS ctr,
        ROUND(SAFE_DIVIDE(clicks, impressions) * 100, 2) AS ctr_percentage
    FROM {{ ref('int_daily_metrics') }}
    WHERE impressions > 0  -- Only include records with impressions for valid CTR
),

weekly AS (
    SELECT
        'weekly' AS grain,
        CAST(week_start_date AS STRING) AS period,
        partner,
        platform,
        clicks,
        impressions,
        SAFE_DIVIDE(clicks, impressions) AS ctr,
        ROUND(SAFE_DIVIDE(clicks, impressions) * 100, 2) AS ctr_percentage
    FROM {{ ref('int_weekly_metrics') }}
    WHERE impressions > 0
),

monthly AS (
    SELECT
        'monthly' AS grain,
        CAST(month_start_date AS STRING) AS period,
        partner,
        platform,
        clicks,
        impressions,
        SAFE_DIVIDE(clicks, impressions) AS ctr,
        ROUND(SAFE_DIVIDE(clicks, impressions) * 100, 2) AS ctr_percentage
    FROM {{ ref('int_monthly_metrics') }}
    WHERE impressions > 0
),

combined AS (
    SELECT * FROM daily
    UNION ALL
    SELECT * FROM weekly
    UNION ALL
    SELECT * FROM monthly
)

SELECT
    grain,
    period,
    partner,
    platform,
    clicks,
    impressions,
    ctr,
    ctr_percentage
FROM combined

ORDER BY
    grain,
    period DESC,
    partner,
    platform
