-- 1. Recupera dalla notifica i dati attesi per lo specifico IUN e recIndex
WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        0 AS target_recindex,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key,
        date_add('day', -10, current_date) AS start_sent_date,
        date_add('day', -1, current_date) AS end_sent_date
),

notification_latest AS (
    SELECT *
    FROM (
        SELECT
            n.*,
            ROW_NUMBER() OVER (
                PARTITION BY n.iun
                ORDER BY n.kinesis_dynamodb_ApproximateCreationDateTime DESC
            ) AS rn
        FROM "cdc_analytics_database"."pn_notifications_json_view" n
        CROSS JOIN params p
        WHERE n.iun = p.target_iun
          AND CAST(
                CAST(n.p_year AS varchar) ||
                LPAD(CAST(n.p_month AS varchar), 2, '0') ||
                LPAD(CAST(n.p_day AS varchar), 2, '0')
              AS integer)
              BETWEEN p.start_partition_key AND p.max_partition_key
          AND TRY_CAST(SUBSTR(n.sentAt, 1, 10) AS date)
              BETWEEN p.start_sent_date AND p.end_sent_date
    )
    WHERE rn = 1
)

SELECT
    n.iun AS n_iun,
    CAST(rec_ordinality - 1 AS integer) AS n_recIndex,
    recipient.recipientId AS n_recipientInternalId,
    n.notificationFeePolicy AS n_notificationFeePolicy,
    n.pagoPaIntMode AS n_pagoPaIntMode,
    TRY_CAST(n.vat AS integer) AS n_vat,
    TRY_CAST(n.paFee AS integer) AS n_paFee,
    n.senderPaId AS n_senderPaId,
    n.senderTaxId AS n_senderTaxId
FROM notification_latest n
CROSS JOIN UNNEST(n.recipients)
    WITH ORDINALITY AS r(recipient, rec_ordinality)
CROSS JOIN params p
WHERE CAST(rec_ordinality - 1 AS integer) = p.target_recindex;

-- 2. Verifica che la coppia IUN/recIndex abbia eventi associati nella timeline

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
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

-- 3. Recupera da pn_notification_delivery_cost i dati effettivi per IUN/recIndex

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        0 AS target_recindex,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
),

delivery_cost_versions AS (
    SELECT
        dc.*,
        ROW_NUMBER() OVER (
            PARTITION BY dc.dynamodb_keys_pk, dc.dynamodb_keys_sk
            ORDER BY dc.kinesis_dynamodb_ApproximateCreationDateTime DESC
        ) AS rn
    FROM "cdc_analytics_database"."pn_notification_delivery_cost_json_view" dc
    CROSS JOIN params p
    WHERE dc.dynamodb_keys_pk = p.target_iun
      AND TRY_CAST(dc.dynamodb_keys_sk AS integer) = p.target_recindex
      AND CAST(
            CAST(dc.p_year AS varchar) ||
            LPAD(CAST(dc.p_month AS varchar), 2, '0') ||
            LPAD(CAST(dc.p_day AS varchar), 2, '0')
          AS integer)
          BETWEEN p.start_partition_key AND p.max_partition_key
)

SELECT
    dynamodb_keys_pk AS dc_iun,
    TRY_CAST(dynamodb_keys_sk AS integer) AS dc_recIndex,
    recipientInternalId AS dc_recipientInternalId,
    notificationFeePolicy AS dc_notificationFeePolicy,
    pagoPaIntMode AS dc_pagoPaIntMode,
    TRY_CAST(vat AS integer) AS dc_vat,
    TRY_CAST(baseCost_paFee AS integer) AS dc_baseCost_paFee,
    senderPaId AS dc_senderPaId,
    senderTaxId AS dc_senderTaxId,
    stream_eventname,
    kinesis_dynamodb_ApproximateCreationDateTime
FROM delivery_cost_versions
WHERE rn = 1
  AND stream_eventname IN ('INSERT', 'MODIFY');