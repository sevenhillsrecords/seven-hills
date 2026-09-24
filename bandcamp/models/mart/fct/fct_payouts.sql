{{ config(materialized='table') }}

SELECT
    sales_report_id AS payout_id,
    transaction_id,
    paypal_transaction_id,
    currency,
    item_total,
    transaction_fee,
    amount_you_received,
    sale_date AS payout_at
FROM {{ ref('stg_bandcamp_sales_report') }}
WHERE item_type = 'payout'