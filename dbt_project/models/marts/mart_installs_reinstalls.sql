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
    ROUND(total_install_cost, 2) AS total_install_cost_rounded
FROM combined

ORDER BY
    grain,
    period DESC,
    partner,
    platform
