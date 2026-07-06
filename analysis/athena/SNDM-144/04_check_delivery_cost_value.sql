--1. CHECK MANUALE - timeline + delivery_cost
WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        0 AS target_recindex,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
),

timeline_base AS (
    SELECT
        t.iun,
        COALESCE(
            TRY_CAST(t.details_recIndex AS integer),
            TRY_CAST(REGEXP_EXTRACT(t.timelineElementId, 'RECINDEX_([0-9]+)', 1) AS integer)
        ) AS recIndex,
        t.category,
        t.timelineElementId,
        TRY_CAST(t.details_sentAttemptMade AS integer) AS sentAttemptMade,
        TRY_CAST(t.details_analogCost AS integer) AS analogCost,
        TRY_CAST(t.details_notificationCost AS integer) AS notificationCost,
        t.details_productType AS productType,
        t.timestamp,

        CASE
            WHEN t.category = 'SEND_ANALOG_DOMICILE'
             AND TRY_CAST(t.details_sentAttemptMade AS integer) = 0
                THEN 'FIRST_ANALOG'

            WHEN t.category = 'SEND_ANALOG_DOMICILE'
             AND TRY_CAST(t.details_sentAttemptMade AS integer) = 1
                THEN 'SECOND_ANALOG'

            WHEN t.category = 'SEND_SIMPLE_REGISTERED_LETTER'
              OR t.timelineElementId LIKE '%SEND_SIMPLE_REGISTERED_LETTER%'
                THEN 'SIMPLE_REGISTERED_LETTER'
        END AS expected_cost_type

    FROM "cdc_analytics_database"."pn_timelines_json_view" t
    CROSS JOIN params p
    WHERE t.iun = p.target_iun
      AND COALESCE(
            TRY_CAST(t.details_recIndex AS integer),
            TRY_CAST(REGEXP_EXTRACT(t.timelineElementId, 'RECINDEX_([0-9]+)', 1) AS integer)
          ) = p.target_recindex
      AND CAST(
            CAST(t.p_year AS varchar) ||
            LPAD(CAST(t.p_month AS varchar), 2, '0') ||
            LPAD(CAST(t.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
      AND t.category IN (
            'SEND_ANALOG_DOMICILE',
            'SEND_SIMPLE_REGISTERED_LETTER'
      )
)

SELECT
    *,
    ROW_NUMBER() OVER (
        PARTITION BY iun, recIndex, expected_cost_type
        ORDER BY timestamp DESC
    ) AS rn
FROM timeline_base
ORDER BY expected_cost_type, timestamp DESC;


-- 2. Verifica presenza su pn_notification_delivery_cost

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
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
)

SELECT
    dynamodb_keys_pk AS iun,
    TRY_CAST(dynamodb_keys_sk AS integer) AS recIndex,

    stream_eventname,
    kinesis_dynamodb_ApproximateCreationDateTime,
    rn,

    TRY_CAST(baseCost_sendFee AS integer) AS baseCost_sendFee,
    TRY_CAST(baseCost_paFee AS integer) AS baseCost_paFee,

    TRY_CAST(firstAnalogCost_cost AS integer) AS firstAnalogCost_cost,
    firstAnalogCost_productType,

    TRY_CAST(secondAnalogCost_cost AS integer) AS secondAnalogCost_cost,
    secondAnalogCost_productType,

    TRY_CAST(simpleRegisteredLetterCost_cost AS integer) AS simpleRegisteredLetterCost_cost,
    simpleRegisteredLetterCost_productType,

    CASE
        WHEN rn = 1 AND stream_eventname = 'REMOVE'
            THEN 'ULTIMO_REMOVE'
        WHEN rn = 1 AND stream_eventname IN ('INSERT', 'MODIFY')
            THEN 'ULTIMO_ATTIVO'
        ELSE 'STORICO'
    END AS stato_record

FROM delivery_cost_versions
ORDER BY kinesis_dynamodb_ApproximateCreationDateTime DESC;


-- 3. Verifica presenza su pn_notifications_cost 

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        0 AS target_recindex,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
),

notification_cost_versions AS (
    SELECT
        nc.iun,
        TRY_CAST(nc.recipientIdx AS integer) AS recIndex,

        COALESCE(
            nc.creditorTaxId_noticeCode,
            nc.dynamodb_keys_creditorTaxId_noticeCode
        ) AS creditorTaxId_noticeCode,

        nc.stream_eventname,
        nc.kinesis_dynamodb_ApproximateCreationDateTime,

        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(
                nc.creditorTaxId_noticeCode,
                nc.dynamodb_keys_creditorTaxId_noticeCode
            )
            ORDER BY nc.kinesis_dynamodb_ApproximateCreationDateTime DESC
        ) AS rn

    FROM "cdc_analytics_database"."pn_notifications_cost_json_view" nc
    CROSS JOIN params p
    WHERE nc.iun = p.target_iun
      AND TRY_CAST(nc.recipientIdx AS integer) = p.target_recindex
      AND CAST(
            CAST(nc.p_year AS varchar) ||
            LPAD(CAST(nc.p_month AS varchar), 2, '0') ||
            LPAD(CAST(nc.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
)

SELECT
    *,
    CASE
        WHEN rn = 1 AND stream_eventname = 'REMOVE'
            THEN 'ULTIMO_REMOVE_ESCLUSO_DAL_PERIMETRO'
        WHEN rn = 1 AND stream_eventname IN ('INSERT', 'MODIFY')
            THEN 'ULTIMO_ATTIVO_NEL_PERIMETRO'
        ELSE 'STORICO'
    END AS stato_notification_cost
FROM notification_cost_versions
ORDER BY kinesis_dynamodb_ApproximateCreationDateTime DESC;