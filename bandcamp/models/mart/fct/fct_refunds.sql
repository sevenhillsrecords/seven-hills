{{ config(materialized='table') }}

SELECT
    sales_report_id AS refund_id,
    transaction_item_id,
    transaction_id,
    paypal_transaction_id,
    catalog_number,
    item_type,
    item_name,
    artist,
    package,
    currency,
    item_price,
    quantity,
    sub_total,
    shipping,
    transaction_fee,
    item_total,
    amount_you_received,
    net_amount,
    sale_date,
    buyer_name,
    buyer_email,
    referer,
    referer_url
FROM {{ ref('stg_bandcamp_sales_report') }}
WHERE item_type = 'refund'