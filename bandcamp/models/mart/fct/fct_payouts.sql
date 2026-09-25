{{ config(materialized='table') }}

SELECT
    sales_report_id AS payout_id,
    transaction_id,
    paypal_transaction_id,
    currency,
    item_total,
    transaction_fee,
    amount_you_received,
    event_timestamp AS payout_timestamp
FROM {{ ref('stg_bandcamp_sales_report') }}
WHERE item_type = 'payout'