/*-----
CHECK MANUALE - KPI payment_info da pn_notifications_cost

Scopo:
verificare che una chiave payment presente su pn_notifications_cost
sia presente e coerente anche su pn_payment_info.

Parametri da valorizzare:
<TARGET_IUN> = IUN da verificare
<TARGET_PAYMENT_KEY> = creditorTaxId##noticeCode
<TARGET_RECIPIENT_IDX> = recipientIdx atteso
------*/


-- 1. Verifica perimetro notification ultimi 10 giorni

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key,
        date_add('day', -10, current_date) AS start_sent_date,
        date_add('day', -1, current_date) AS end_sent_date
)

SELECT DISTINCT
    n.iun,
    n.sentAt,
    TRY_CAST(SUBSTR(n.sentAt, 1, 10) AS date) AS sentAt_date,
    n.stream_eventname,
    n.p_year,
    n.p_month,
    n.p_day
FROM "cdc_analytics_database"."pn_notifications_json_view" n
CROSS JOIN params p
WHERE n.iun = p.target_iun
  AND CAST(
        CAST(n.p_year AS varchar) ||
        LPAD(CAST(n.p_month AS varchar), 2, '0') ||
        LPAD(CAST(n.p_day AS varchar), 2, '0')
      AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
  AND TRY_CAST(SUBSTR(n.sentAt, 1, 10) AS date)
      BETWEEN p.start_sent_date AND p.end_sent_date
ORDER BY n.sentAt;


-- 2. Verifica presenza su pn_notifications_cost

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        '<TARGET_PAYMENT_KEY>' AS target_payment_key,
        <TARGET_RECIPIENT_IDX> AS target_recipient_idx,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
),

notification_cost_versions AS (
    SELECT
        nc.*,
        ROW_NUMBER() OVER (
            PARTITION BY
                nc.iun,
                TRY_CAST(nc.recipientIdx AS integer),
                nc.creditorTaxId_noticeCode
            ORDER BY nc.kinesis_dynamodb_ApproximateCreationDateTime DESC
        ) AS rn
    FROM "cdc_analytics_database"."pn_notifications_cost_json_view" nc
    CROSS JOIN params p
    WHERE nc.iun = p.target_iun
      AND nc.creditorTaxId_noticeCode = p.target_payment_key
      AND TRY_CAST(nc.recipientIdx AS integer) = p.target_recipient_idx
      AND CAST(
            CAST(nc.p_year AS varchar) ||
            LPAD(CAST(nc.p_month AS varchar), 2, '0') ||
            LPAD(CAST(nc.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
)

SELECT
    iun,
    TRY_CAST(recipientIdx AS integer) AS recipientIdx,
    recipientType,
    creditorTaxId_noticeCode,
    SPLIT_PART(creditorTaxId_noticeCode, '##', 1) AS creditorTaxId,
    SPLIT_PART(creditorTaxId_noticeCode, '##', 2) AS noticeCode,
    dynamodb_keys_creditorTaxId_noticeCode,
    stream_eventname,
    kinesis_dynamodb_ApproximateCreationDateTime,
    p_year,
    p_month,
    p_day,
    p_hour,
    rn,
    CASE
        WHEN rn = 1 THEN 'ULTIMO_EVENTO_NOTIFICATION_COST'
        ELSE 'EVENTO_STORICO'
    END AS stato_record
FROM notification_cost_versions
ORDER BY kinesis_dynamodb_ApproximateCreationDateTime DESC;

-- 3. Verifica presenza su pn_notifications_cost

WITH params AS (
    SELECT
        'AUEL-GZHG-ZYLG-202606-L-1' AS target_iun,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
)

SELECT
    t.iun AS tl_iun,
    COALESCE(
        TRY_CAST(t.details_recIndex AS integer),
        TRY_CAST(REGEXP_EXTRACT(t.timelineElementId, 'RECINDEX_([0-9]+)', 1) AS integer)
    ) AS tl_recIndex,
    t.category AS tl_category,
    t.timelineElementId AS tl_timelineElementId,
    t.timestamp AS tl_timestamp,
    t.details_recIndex
FROM "cdc_analytics_database"."pn_timelines_json_view" t
CROSS JOIN params p
WHERE t.iun = p.target_iun
  AND CAST(
        CAST(t.p_year AS varchar) ||
        LPAD(CAST(t.p_month AS varchar), 2, '0') ||
        LPAD(CAST(t.p_day AS varchar), 2, '0')
      AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
  AND t.timestamp IS NOT NULL
ORDER BY t.timestamp;



-- 4. Verifica pn_payment_info solo se la chiave esiste su pn_notifications_cost

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        '<TARGET_PAYMENT_KEY>' AS target_payment_key,
        <TARGET_RECIPIENT_IDX> AS target_recipient_idx,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
),

notification_cost_last AS (
    SELECT *
    FROM (
        SELECT
            nc.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    nc.iun,
                    TRY_CAST(nc.recipientIdx AS integer),
                    nc.creditorTaxId_noticeCode
                ORDER BY nc.kinesis_dynamodb_ApproximateCreationDateTime DESC
            ) AS rn
        FROM "cdc_analytics_database"."pn_notifications_cost_json_view" nc
        CROSS JOIN params p
        WHERE nc.iun = p.target_iun
          AND nc.creditorTaxId_noticeCode = p.target_payment_key
          AND TRY_CAST(nc.recipientIdx AS integer) = p.target_recipient_idx
          AND CAST(
                CAST(nc.p_year AS varchar) ||
                LPAD(CAST(nc.p_month AS varchar), 2, '0') ||
                LPAD(CAST(nc.p_day AS varchar), 2, '0')
              AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
    )
    WHERE rn = 1
)

SELECT
    pi.dynamodb_keys_pk,
    pi.iun,
    TRY_CAST(pi.recIndex AS integer) AS recIndex,
    pi.applyCost,
    pi.stream_eventname,
    pi.kinesis_dynamodb_ApproximateCreationDateTime,
    pi.p_year,
    pi.p_month,
    pi.p_day,
    pi.p_hour
FROM notification_cost_last nc
INNER JOIN "cdc_analytics_database"."pn_payment_info_json_view" pi
    ON pi.dynamodb_keys_pk = nc.creditorTaxId_noticeCode
CROSS JOIN params p
WHERE CAST(
        CAST(pi.p_year AS varchar) ||
        LPAD(CAST(pi.p_month AS varchar), 2, '0') ||
        LPAD(CAST(pi.p_day AS varchar), 2, '0')
      AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
ORDER BY pi.kinesis_dynamodb_ApproximateCreationDateTime DESC;