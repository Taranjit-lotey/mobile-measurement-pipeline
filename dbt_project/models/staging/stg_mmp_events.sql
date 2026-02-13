{{
    config(
        materialized='view',
        description='Cleaned and typed mobile measurement partner events from GCS'
    )
}}

WITH source AS (
    SELECT * FROM {{ source('raw', 'mmp_events_external') }}
),

cleaned AS (
    SELECT
        -- Primary key
        event_id,

        -- Timestamp parsing and date dimensions
        PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', timestamp) AS event_timestamp,
        CAST(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', timestamp) AS DATE) AS event_date,

        -- Event attributes (normalized)
        LOWER(event_type) AS event_type,
        LOWER(partner) AS partner,
        CAST(cost_usd AS FLOAT64) AS cost_usd,

        -- App and campaign identifiers
        app_id,
        campaign_id,

        -- Device attributes (normalized)
        UPPER(platform) AS platform,
        UPPER(country_code) AS country_code,

        -- Derived date dimensions for aggregations
        EXTRACT(YEAR FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', timestamp)) AS year,
        EXTRACT(MONTH FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', timestamp)) AS month,
        EXTRACT(WEEK FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', timestamp)) AS week,
        EXTRACT(DAYOFWEEK FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', timestamp)) AS day_of_week

    FROM source

    -- Data quality filters
    WHERE timestamp IS NOT NULL
        AND event_type IN ('install', 'reinstall', 'click', 'impression')
        AND cost_usd >= 0
)

SELECT * FROM cleaned
