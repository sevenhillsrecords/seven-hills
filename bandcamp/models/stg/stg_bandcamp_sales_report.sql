{{ config(materialized='table') }}

SELECT
    -- Identifiers
    {{ dbt_utils.generate_surrogate_key(['bandcamp_transaction_id', 'bandcamp_transaction_item_id']) }} AS sales_report_id,
    CAST(bandcamp_transaction_item_id AS VARCHAR) AS transaction_item_id,
    CAST(bandcamp_transaction_id AS VARCHAR) AS transaction_id,
    CAST(paypal_transaction_id AS VARCHAR) AS paypal_transaction_id,
    CAST(catalog_number AS VARCHAR) AS catalog_number,
    CAST(item_type AS VARCHAR) AS item_type,

    -- Item & Artist Details
    CAST(item_name AS VARCHAR) AS item_name,
    CAST(artist AS VARCHAR) AS artist,
    CAST(package AS VARCHAR) AS package,
    CAST(item_url AS VARCHAR) AS item_url,

    -- Financials & Pricing
    CAST(currency AS VARCHAR) AS currency,
    CAST(item_price AS DECIMAL(10,2)) AS item_price,
    CAST(quantity AS INTEGER) AS quantity,
    CAST(sub_total AS DECIMAL(10,2)) AS sub_total,
    CAST(shipping AS DECIMAL(10,2)) AS shipping,
    CAST(transaction_fee AS DECIMAL(10,2)) AS transaction_fee,
    CAST(item_total AS DECIMAL(10,2)) AS item_total,
    CAST(amount_you_received AS DECIMAL(10,2)) AS amount_you_received,
    CAST(net_amount AS DECIMAL(10,2)) AS net_amount,
    CAST(additional_fan_contribution AS DECIMAL(10,2)) AS additional_fan_contribution,

    -- Timestamps (Converting Bandcamp's string date format)
    strptime(date, '%d %b %Y %H:%M:%S %Z')::TIMESTAMP AS sale_date,
    strptime(ship_date, '%d %b %Y %H:%M:%S %Z')::TIMESTAMP AS ship_date,

    -- Buyer Information
    CAST(buyer_name AS VARCHAR) AS buyer_name,
    CAST(buyer_email AS VARCHAR) AS buyer_email,
    CAST(buyer_note AS VARCHAR) AS buyer_note,

    -- Shipping & Destination Details
    CAST(ship_to_name AS VARCHAR) AS ship_to_name,
    CAST(ship_to_street AS VARCHAR) AS ship_to_street,
    CAST(ship_to_city AS VARCHAR) AS ship_to_city,
    CAST(ship_to_state AS VARCHAR) AS ship_to_state,
    CAST(ship_to_zip AS VARCHAR) AS ship_to_zip,
    CAST(ship_to_country AS VARCHAR) AS ship_to_country,
    CAST(ship_notes AS VARCHAR) AS ship_notes,

    -- Traffic / Acquisition
    CAST(referer AS VARCHAR) AS referer,
    CAST(referer_url AS VARCHAR) AS referer_url,

FROM {{ source('bandcamp', 'bandcamp_raw_sales') }}