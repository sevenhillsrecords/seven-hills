{{ config(materialized='table') }}

WITH unique_products AS (
    SELECT DISTINCT
        item_name,
        artist,
        package,
        catalog_number,
        item_url,
    FROM {{ ref('stg_bandcamp_sales_report') }}
    WHERE item_name IS NOT NULL
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['item_name', 'package', 'item_url']) }} AS product_key,
    item_name,
    artist,
    package,
    catalog_number,
    item_url,
FROM unique_products