{{
    config(
        materialized='table',
        description='Installs and reinstalls aggregated across multiple time grains (daily/weekly/monthly)'
    )
}}

WITH daily AS (
    SELECT
        'daily' AS grain,
        CAST(event_date AS STRING) AS period,
        partner,
        platform,
        installs,
        reinstalls,
        installs + reinstalls AS total_install_events,
        install_cost + reinstall_cost AS total_install_cost
    FROM {{ ref('int_daily_metrics') }}
),

weekly AS (
    SELECT
        'weekly' AS grain,
        CAST(week_start_date AS STRING) AS period,
        partner,
        platform,
        installs,
        reinstalls,
        installs + reinstalls AS total_install_events,
        install_cost + reinstall_cost AS total_install_cost
    FROM {{ ref('int_weekly_metrics') }}
),

monthly AS (
    SELECT
        'monthly' AS grain,
        CAST(month_start_date AS STRING) AS period,
        partner,
        platform,
        installs,
        reinstalls,
        installs + reinstalls AS total_install_events,
        install_cost + reinstall_cost AS total_install_cost
    FROM {{ ref('int_monthly_metrics') }}
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
    reinstalls,
    total_install_events,
    total_install_cost,
    ROUND(total_install_cost, 2) AS total_install_cost_rounded,
    -- Retention & conversion metrics
    ROUND(SAFE_DIVIDE(reinstalls, installs) * 100, 2) AS reinstall_rate_percentage,
    ROUND(SAFE_DIVIDE(installs, total_install_events) * 100, 2) AS new_user_percentage,
    -- Growth indicators
    LAG(installs) OVER (
        PARTITION BY grain, partner, platform
        ORDER BY period
    ) AS previous_period_installs,
    ROUND(
        SAFE_DIVIDE(
            installs - LAG(installs) OVER (
                PARTITION BY grain, partner, platform
                ORDER BY period
            ),
            LAG(installs) OVER (
                PARTITION BY grain, partner, platform
                ORDER BY period
            )
        ) * 100, 2
    ) AS install_growth_rate_percentage,
    -- Volume tiers
    CASE
        WHEN installs >= 50 THEN 'High Volume'
        WHEN installs >= 20 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END AS volume_tier,
    -- Cumulative installs (running total)
    SUM(installs) OVER (
        PARTITION BY grain, partner, platform
        ORDER BY period
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_installs,
    -- Partner market share
    ROUND(
        SAFE_DIVIDE(
            installs,
            SUM(installs) OVER (PARTITION BY grain, period, platform)
        ) * 100, 2
    ) AS partner_market_share_percentage,
    -- Partner ranking by volume
    RANK() OVER (
        PARTITION BY grain, period, platform
        ORDER BY installs DESC
    ) AS partner_rank_by_volume
FROM combined

ORDER BY
    grain,
    period DESC,
    partner,
    platform
