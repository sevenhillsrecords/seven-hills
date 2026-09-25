{{ config(materialized='table') }}

WITH price_changes AS (
    SELECT DISTINCT
        item_name,
        catalog_number,
        artist,
        package,
        item_url,
        item_price,
        sale_date AS effective_date
    FROM {{ ref('stg_bandcamp_sales_report') }}
    WHERE item_name IS NOT NULL
        AND item_price IS NOT NULL
),

add_next_date AS (
    SELECT
        item_name,
        package,
        catalog_number,
        item_url,
        item_price,
        effective_date AS valid_from,
        LEAD(effective_date) OVER (
            PARTITION BY item_name, package, item_url
            ORDER BY effective_date ASC
        ) AS valid_to
    FROM price_changes
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['item_name', 'package', 'item_url', 'valid_from']) }} AS product_version_key,
    {{ dbt_utils.generate_surrogate_key(['item_name', 'package', 'item_url']) }} AS product_key,
    item_name,
    package,
    catalog_number,
    item_url,
    item_price,
    valid_from,
    valid_to,
    CASE 
        WHEN valid_to IS NULL THEN TRUE 
        ELSE FALSE 
    END AS is_current
FROM add_next_date