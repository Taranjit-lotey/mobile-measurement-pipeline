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
    cpi_blended_rounded
FROM combined

ORDER BY
    grain,
    period DESC,
    partner,
    platform
