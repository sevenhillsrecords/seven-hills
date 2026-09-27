{{ config(materialized='table') }}

WITH cleaned_data AS (
    SELECT
        -- Clean identifiers first so hashing and partitioning are consistent
        TRY_CAST(TRY_CAST({{ clean_string('bandcamp_transaction_item_id') }} AS DOUBLE) AS BIGINT) AS transaction_item_id,
        TRY_CAST(TRY_CAST({{ clean_string('bandcamp_transaction_id') }} AS DOUBLE) AS BIGINT) AS transaction_id,
        
        {{ clean_string('paypal_transaction_id') }} AS paypal_transaction_id,
        {{ clean_string('catalog_number') }} AS catalog_number,
        {{ clean_string('item_type') }} AS item_type,

        -- Item & Artist Details
        {{ clean_string('item_name') }} AS item_name,
        {{ clean_string('artist') }} AS artist,
        {{ clean_string('package') }} AS package,
        {{ clean_string('item_url') }} AS item_url,

        -- Financials & Pricing
        {{ clean_string('currency') }} AS currency,
        TRY_CAST(item_price AS DECIMAL(10,2)) AS item_price,
        TRY_CAST(quantity AS INTEGER) AS quantity,
        TRY_CAST(sub_total AS DECIMAL(10,2)) AS sub_total,
        TRY_CAST(shipping AS DECIMAL(10,2)) AS shipping,
        TRY_CAST(transaction_fee AS DECIMAL(10,2)) AS transaction_fee,
        TRY_CAST(item_total AS DECIMAL(10,2)) AS item_total,
        TRY_CAST(amount_you_received AS DECIMAL(10,2)) AS amount_you_received,
        TRY_CAST(net_amount AS DECIMAL(10,2)) AS net_amount,
        TRY_CAST(additional_fan_contribution AS DECIMAL(10,2)) AS additional_fan_contribution,

        -- Timestamps
        CASE 
            WHEN date IS NULL OR date IN ('nan', 'None', '') OR trim(date) = '' THEN NULL
            ELSE strptime(date, '%d %b %Y %H:%M:%S %Z')::TIMESTAMP 
        END AS event_timestamp,
        
        CASE 
            WHEN ship_date IS NULL OR ship_date IN ('nan', 'None', '') OR trim(ship_date) = '' THEN NULL
            ELSE strptime(ship_date, '%d %b %Y %H:%M:%S %Z')::TIMESTAMP 
        END AS ship_timestamp,

        -- Buyer Information
        {{ clean_string('buyer_name') }} AS buyer_name,
        {{ clean_string('buyer_email') }} AS buyer_email,
        {{ clean_string('buyer_note') }} AS buyer_note,

        -- Shipping & Destination Details
        {{ clean_string('ship_to_name') }} AS ship_to_name,
        {{ clean_string('ship_to_street') }} AS ship_to_street,
        {{ clean_string('ship_to_city') }} AS ship_to_city,
        {{ clean_string('ship_to_state') }} AS ship_to_state,
        {{ clean_string('ship_to_zip') }} AS ship_to_zip,
        {{ clean_string('ship_to_country') }} AS ship_to_country,
        {{ clean_string('ship_notes') }} AS ship_notes,

        -- Traffic / Acquisition
        {{ clean_string('referer') }} AS referer,
        {{ clean_string('referer_url') }} AS referer_url

    FROM {{ source('bandcamp', 'bandcamp_raw_sales') }}
),

add_surrogate_key AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'transaction_id', 
            'transaction_item_id', 
            'paypal_transaction_id'
        ]) }} AS sales_report_id,
        *
    FROM cleaned_data
),

ranked_data AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY sales_report_id
            ORDER BY event_timestamp ASC NULLS LAST
        ) AS rn
    FROM add_surrogate_key
)

SELECT * EXCLUDE (rn) FROM ranked_data
WHERE rn = 1