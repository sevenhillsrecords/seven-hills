{{ config(materialized='table') }}

WITH cleaned_source AS (
    SELECT
        bandcamp_transaction_id,
        bandcamp_transaction_item_id,
        paypal_transaction_id,
        catalog_number,
        item_type,
        item_name,
        artist,
        package,
        item_url,
        currency,
        item_price,
        quantity,
        sub_total,
        shipping,
        transaction_fee,
        item_total,
        amount_you_received,
        net_amount,
        additional_fan_contribution,
        date,
        ship_date,
        buyer_name,
        buyer_email,
        buyer_note,
        ship_to_name,
        ship_to_street,
        ship_to_city,
        ship_to_state,
        ship_to_zip,
        ship_to_country,
        ship_notes,
        referer,
        referer_url
    FROM {{ source('bandcamp', 'bandcamp_raw_sales') }}
),

ranked_sales AS (
    SELECT
        *,
        -- Assign a row number per transaction and item ID combination
        -- ORDER BY event_timestamp (or a file load timestamp if you have one) determines which is 'first'
        ROW_NUMBER() OVER (
            PARTITION BY bandcamp_transaction_id, bandcamp_transaction_item_id 
            ORDER BY 
                CASE 
                    WHEN date IS NULL OR date IN ('nan', 'None', '') OR trim(date) = '' THEN NULL
                    ELSE strptime(date, '%d %b %Y %H:%M:%S %Z')::TIMESTAMP 
                END ASC
        ) AS rn
    FROM cleaned_source
),

transformed AS (
    SELECT
        -- Identifiers
        {{ dbt_utils.generate_surrogate_key(['bandcamp_transaction_id', 'bandcamp_transaction_item_id']) }} AS sales_report_id,
        NULLIF(CAST(bandcamp_transaction_item_id AS VARCHAR), 'nan') AS transaction_item_id,
        NULLIF(CAST(bandcamp_transaction_id AS VARCHAR), 'nan') AS transaction_id,
        NULLIF(CAST(paypal_transaction_id AS VARCHAR), 'nan') AS paypal_transaction_id,
        NULLIF(CAST(catalog_number AS VARCHAR), 'nan') AS catalog_number,
        NULLIF(CAST(item_type AS VARCHAR), 'nan') AS item_type,

        -- Item & Artist Details
        NULLIF(NULLIF(CAST(item_name AS VARCHAR), 'nan'), 'None') AS item_name,
        NULLIF(NULLIF(CAST(artist AS VARCHAR), 'nan'), 'None') AS artist,
        NULLIF(NULLIF(CAST(package AS VARCHAR), 'nan'), 'None') AS package,
        NULLIF(NULLIF(CAST(item_url AS VARCHAR), 'nan'), 'None') AS item_url,

        -- Financials & Pricing 
        NULLIF(NULLIF(CAST(currency AS VARCHAR), 'nan'), 'None') AS currency,
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
        END AS ship_date,

        -- Buyer Information
        NULLIF(NULLIF(CAST(buyer_name AS VARCHAR), 'nan'), 'None') AS buyer_name,
        NULLIF(NULLIF(CAST(buyer_email AS VARCHAR), 'nan'), 'None') AS buyer_email,
        NULLIF(NULLIF(CAST(buyer_note AS VARCHAR), 'nan'), 'None') AS buyer_note,

        -- Shipping & Destination Details
        NULLIF(NULLIF(CAST(ship_to_name AS VARCHAR), 'nan'), 'None') AS ship_to_name,
        NULLIF(NULLIF(CAST(ship_to_street AS VARCHAR), 'nan'), 'None') AS ship_to_street,
        NULLIF(NULLIF(CAST(ship_to_city AS VARCHAR), 'nan'), 'None') AS ship_to_city,
        NULLIF(NULLIF(CAST(ship_to_state AS VARCHAR), 'nan'), 'None') AS ship_to_state,
        NULLIF(NULLIF(CAST(ship_to_zip AS VARCHAR), 'nan'), 'None') AS ship_to_zip,
        NULLIF(NULLIF(CAST(ship_to_country AS VARCHAR), 'nan'), 'None') AS ship_to_country,
        NULLIF(NULLIF(CAST(ship_notes AS VARCHAR), 'nan'), 'None') AS ship_notes,

        -- Traffic / Acquisition
        NULLIF(NULLIF(CAST(referer AS VARCHAR), 'nan'), 'None') AS referer,
        NULLIF(NULLIF(CAST(referer_url AS VARCHAR), 'nan'), 'None') AS referer_url

    FROM ranked_sales
    WHERE rn = 1
)

SELECT * FROM transformed