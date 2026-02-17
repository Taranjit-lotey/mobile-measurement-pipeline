{{
    config(
        materialized='table',
        description='Cost per install (CPI) metrics aggregated across multiple time grains (daily/weekly/monthly)'
    )
}}

WITH daily AS (
    SELECT
        'daily' AS grain,
        CAST(event_date AS STRING) AS period,
        partner,
        platform,
        installs,
        install_cost,
        total_cost,
        SAFE_DIVIDE(install_cost, installs) AS cpi_direct,
        SAFE_DIVIDE(total_cost, installs) AS cpi_blended,
        ROUND(SAFE_DIVIDE(install_cost, installs), 2) AS cpi_direct_rounded,
        ROUND(SAFE_DIVIDE(total_cost, installs), 2) AS cpi_blended_rounded
    FROM {{ ref('int_daily_metrics') }}
    WHERE installs > 0  -- Only include records with installs for valid CPI
),

weekly AS (
    SELECT
        'weekly' AS grain,
        CAST(week_start_date AS STRING) AS period,
        partner,
        platform,
        installs,
        install_cost,
        total_cost,
        SAFE_DIVIDE(install_cost, installs) AS cpi_direct,
        SAFE_DIVIDE(total_cost, installs) AS cpi_blended,
        ROUND(SAFE_DIVIDE(install_cost, installs), 2) AS cpi_direct_rounded,
        ROUND(SAFE_DIVIDE(total_cost, installs), 2) AS cpi_blended_rounded
    FROM {{ ref('int_weekly_metrics') }}
    WHERE installs > 0
),

monthly AS (
    SELECT
        'monthly' AS grain,
        CAST(month_start_date AS STRING) AS period,
        partner,
        platform,
        installs,
        install_cost,
        total_cost,
        SAFE_DIVIDE(install_cost, installs) AS cpi_direct,
        SAFE_DIVIDE(total_cost, installs) AS cpi_blended,
        ROUND(SAFE_DIVIDE(install_cost, installs), 2) AS cpi_direct_rounded,
        ROUND(SAFE_DIVIDE(total_cost, installs), 2) AS cpi_blended_rounded
    FROM {{ ref('int_monthly_metrics') }}
    WHERE installs > 0
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
    installs,
    install_cost,
    total_cost,
    cpi_direct,
    cpi_blended,
    cpi_direct_rounded,
    cpi_blended_rounded,
    -- Cost efficiency metrics
    ROUND((total_cost - install_cost), 2) AS pre_install_cost,
    ROUND(SAFE_DIVIDE(total_cost - install_cost, installs), 2) AS cost_per_funnel_step,
    -- Cost efficiency tier
    CASE
        WHEN cpi_blended_rounded <= 3.0 THEN 'Efficient'
        WHEN cpi_blended_rounded <= 6.0 THEN 'Moderate'
        ELSE 'Expensive'
    END AS cost_efficiency_tier,
    -- Trend analysis
    LAG(cpi_blended_rounded) OVER (
        PARTITION BY grain, partner, platform
        ORDER BY period
    ) AS previous_period_cpi,
    ROUND(
        cpi_blended_rounded - LAG(cpi_blended_rounded) OVER (
            PARTITION BY grain, partner, platform
            ORDER BY period
        ), 2
    ) AS cpi_change,
    -- Cost optimization score (lower CPI = higher score)
    ROUND(100 - (cpi_blended_rounded * 10), 1) AS cost_optimization_score,
    -- Platform benchmark
    ROUND(AVG(cpi_blended_rounded) OVER (
        PARTITION BY grain, platform
    ), 2) AS platform_avg_cpi,
    -- Partner efficiency ranking
    RANK() OVER (
        PARTITION BY grain, period, platform
        ORDER BY cpi_blended_rounded ASC
    ) AS partner_rank_by_efficiency
FROM combined

ORDER BY
    grain,
    period DESC,
    partner,
    platform
