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
        
        -- Text columns cleaned for 'nan', 'None', empty strings, and whitespace
        CASE WHEN bandcamp_transaction_item_id IS NULL OR bandcamp_transaction_item_id IN ('nan', 'None', '') OR trim(bandcamp_transaction_item_id) = '' THEN NULL ELSE CAST(bandcamp_transaction_item_id AS VARCHAR) END AS transaction_item_id,
        CASE WHEN bandcamp_transaction_id IS NULL OR bandcamp_transaction_id IN ('nan', 'None', '') OR trim(bandcamp_transaction_id) = '' THEN NULL ELSE CAST(bandcamp_transaction_id AS VARCHAR) END AS transaction_id,
        CASE WHEN paypal_transaction_id IS NULL OR paypal_transaction_id IN ('nan', 'None', '') OR trim(paypal_transaction_id) = '' THEN NULL ELSE CAST(paypal_transaction_id AS VARCHAR) END AS paypal_transaction_id,
        CASE WHEN catalog_number IS NULL OR catalog_number IN ('nan', 'None', '') OR trim(catalog_number) = '' THEN NULL ELSE CAST(catalog_number AS VARCHAR) END AS catalog_number,
        CASE WHEN item_type IS NULL OR item_type IN ('nan', 'None', '') OR trim(item_type) = '' THEN NULL ELSE CAST(item_type AS VARCHAR) END AS item_type,

        -- Item & Artist Details
        CASE WHEN item_name IS NULL OR item_name IN ('nan', 'None', '') OR trim(item_name) = '' THEN NULL ELSE CAST(item_name AS VARCHAR) END AS item_name,
        CASE WHEN artist IS NULL OR artist IN ('nan', 'None', '') OR trim(artist) = '' THEN NULL ELSE CAST(artist AS VARCHAR) END AS artist,
        CASE WHEN package IS NULL OR package IN ('nan', 'None', '') OR trim(package) = '' THEN NULL ELSE CAST(package AS VARCHAR) END AS package,
        CASE WHEN item_url IS NULL OR item_url IN ('nan', 'None', '') OR trim(item_url) = '' THEN NULL ELSE CAST(item_url AS VARCHAR) END AS item_url,

        -- Financials & Pricing (TRY_CAST automatically handles blanks, nan, and None as NULL)
        CASE WHEN currency IS NULL OR currency IN ('nan', 'None', '') OR trim(currency) = '' THEN NULL ELSE CAST(currency AS VARCHAR) END AS currency,
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
        CASE WHEN buyer_name IS NULL OR buyer_name IN ('nan', 'None', '') OR trim(buyer_name) = '' THEN NULL ELSE CAST(buyer_name AS VARCHAR) END AS buyer_name,
        CASE WHEN buyer_email IS NULL OR buyer_email IN ('nan', 'None', '') OR trim(buyer_email) = '' THEN NULL ELSE CAST(buyer_email AS VARCHAR) END AS buyer_email,
        CASE WHEN buyer_note IS NULL OR buyer_note IN ('nan', 'None', '') OR trim(buyer_note) = '' THEN NULL ELSE CAST(buyer_note AS VARCHAR) END AS buyer_note,

        -- Shipping & Destination Details
        CASE WHEN ship_to_name IS NULL OR ship_to_name IN ('nan', 'None', '') OR trim(ship_to_name) = '' THEN NULL ELSE CAST(ship_to_name AS VARCHAR) END AS ship_to_name,
        CASE WHEN ship_to_street IS NULL OR ship_to_street IN ('nan', 'None', '') OR trim(ship_to_street) = '' THEN NULL ELSE CAST(ship_to_street AS VARCHAR) END AS ship_to_street,
        CASE WHEN ship_to_city IS NULL OR ship_to_city IN ('nan', 'None', '') OR trim(ship_to_city) = '' THEN NULL ELSE CAST(ship_to_city AS VARCHAR) END AS ship_to_city,
        CASE WHEN ship_to_state IS NULL OR ship_to_state IN ('nan', 'None', '') OR trim(ship_to_state) = '' THEN NULL ELSE CAST(ship_to_state AS VARCHAR) END AS ship_to_state,
        CASE WHEN ship_to_zip IS NULL OR ship_to_zip IN ('nan', 'None', '') OR trim(ship_to_zip) = '' THEN NULL ELSE CAST(ship_to_zip AS VARCHAR) END AS ship_to_zip,
        CASE WHEN ship_to_country IS NULL OR ship_to_country IN ('nan', 'None', '') OR trim(ship_to_country) = '' THEN NULL ELSE CAST(ship_to_country AS VARCHAR) END AS ship_to_country,
        CASE WHEN ship_notes IS NULL OR ship_notes IN ('nan', 'None', '') OR trim(ship_notes) = '' THEN NULL ELSE CAST(ship_notes AS VARCHAR) END AS ship_notes,

        -- Traffic / Acquisition
        CASE WHEN referer IS NULL OR referer IN ('nan', 'None', '') OR trim(referer) = '' THEN NULL ELSE CAST(referer AS VARCHAR) END AS referer,
        CASE WHEN referer_url IS NULL OR referer_url IN ('nan', 'None', '') OR trim(referer_url) = '' THEN NULL ELSE CAST(referer_url AS VARCHAR) END AS referer_url

    FROM ranked_sales
    WHERE rn = 1
)

SELECT * FROM transformed