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
    ctr_percentage,
    -- Performance indicators
    CASE
        WHEN ctr_percentage >= 5.0 THEN 'High'
        WHEN ctr_percentage >= 2.0 THEN 'Medium'
        ELSE 'Low'
    END AS performance_tier,
    -- Engagement score (weighted combination of CTR and volume)
    ROUND((ctr_percentage * 0.7) + (LEAST(clicks / 100.0, 10) * 0.3), 2) AS engagement_score,
    -- Trend analysis using window functions
    LAG(ctr_percentage) OVER (
        PARTITION BY grain, partner, platform
        ORDER BY period
    ) AS previous_period_ctr,
    ROUND(
        ctr_percentage - LAG(ctr_percentage) OVER (
            PARTITION BY grain, partner, platform
            ORDER BY period
        ), 2
    ) AS ctr_change,
    -- Average CTR for benchmarking
    ROUND(AVG(ctr_percentage) OVER (
        PARTITION BY grain, platform
    ), 2) AS platform_avg_ctr,
    -- Partner ranking within platform
    RANK() OVER (
        PARTITION BY grain, period, platform
        ORDER BY ctr_percentage DESC
    ) AS partner_rank_by_ctr
FROM combined

ORDER BY
    grain,
    period DESC,
    partner,
    platform
