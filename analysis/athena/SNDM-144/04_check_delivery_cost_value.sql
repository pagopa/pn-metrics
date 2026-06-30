WITH params AS (
    SELECT
        'TVKN-EWZH-EDXY-202606-P-1' AS target_iun,
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
            ELSE 'ALTRO_EVENTO'
        END AS expected_cost_type,

        TRY_CAST(t.details_analogCost AS integer) AS timeline_analogCost,
        TRY_CAST(t.details_notificationCost AS integer) AS timeline_notificationCost,

        t.timestamp,
        t.p_year,
        t.p_month,
        t.p_day,
        t.p_hour

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
      AND t.timestamp IS NOT NULL
      AND t.category IN (
            'SEND_ANALOG_DOMICILE',
            'SEND_SIMPLE_REGISTERED_LETTER'
      )
),

timeline_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                iun,
                recIndex,
                expected_cost_type
            ORDER BY timestamp DESC
        ) AS rn
    FROM timeline_base
    WHERE expected_cost_type <> 'ALTRO_EVENTO'
)

SELECT
    iun,
    recIndex,
    category,
    timelineElementId,
    sentAttemptMade,
    expected_cost_type,
    timeline_analogCost,
    timeline_notificationCost,
    timestamp,
    p_year,
    p_month,
    p_day,
    p_hour,
    rn,

    CASE
        WHEN rn = 1 THEN 'ULTIMO_EVENTO_PER_TIPO_COSTO'
        ELSE 'EVENTO_STORICO_PER_TIPO_COSTO'
    END AS stato_timeline

FROM timeline_ranked
ORDER BY
    expected_cost_type,
    timestamp DESC;






WITH params AS (
    SELECT
        'TVKN-EWZH-EDXY-202606-P-1' AS target_iun,
        0 AS target_recindex,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
),

delivery_cost_versions AS (
    SELECT
        dc.*,

        ROW_NUMBER() OVER (
            PARTITION BY
                dc.dynamodb_keys_pk,
                dc.dynamodb_keys_sk
            ORDER BY
                dc.kinesis_dynamodb_ApproximateCreationDateTime DESC
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
    dc.dynamodb_keys_pk AS iun,
    TRY_CAST(dc.dynamodb_keys_sk AS integer) AS recIndex,

    TRY_CAST(dc.baseCost_sendFee AS integer) AS baseCost_sendFee,
    TRY_CAST(dc.baseCost_paFee AS integer) AS baseCost_paFee,

    TRY_CAST(dc.firstAnalogCost_cost AS integer) AS firstAnalogCost_cost,
    dc.firstAnalogCost_productType AS firstAnalogCost_productType,

    TRY_CAST(dc.secondAnalogCost_cost AS integer) AS secondAnalogCost_cost,
    dc.secondAnalogCost_productType AS secondAnalogCost_productType,

    TRY_CAST(dc.simpleRegisteredLetterCost_cost AS integer) AS simpleRegisteredLetterCost_cost,
    dc.simpleRegisteredLetterCost_productType AS simpleRegisteredLetterCost_productType,

    dc.stream_eventname,
    dc.kinesis_dynamodb_ApproximateCreationDateTime,

    dc.p_year,
    dc.p_month,
    dc.p_day,
    dc.p_hour,

    dc.rn,

    CASE
        WHEN dc.rn = 1 AND dc.stream_eventname = 'REMOVE'
            THEN 'ULTIMO_EVENTO_REMOVE'

        WHEN dc.rn = 1 AND dc.stream_eventname IN ('INSERT', 'MODIFY')
            THEN 'ULTIMO_EVENTO_ATTIVO'

        ELSE 'EVENTO_STORICO'
    END AS stato_record,

    CASE
        WHEN dc.rn = 1
         AND dc.stream_eventname IN ('INSERT', 'MODIFY')
         AND TRY_CAST(dc.secondAnalogCost_cost AS integer) IS NULL
            THEN 'SECOND_ANALOG_COST_NULL'

        WHEN dc.rn = 1
         AND dc.stream_eventname IN ('INSERT', 'MODIFY')
         AND TRY_CAST(dc.secondAnalogCost_cost AS integer) = 0
            THEN 'SECOND_ANALOG_COST_ZERO'

        WHEN dc.rn = 1
         AND dc.stream_eventname IN ('INSERT', 'MODIFY')
         AND TRY_CAST(dc.secondAnalogCost_cost AS integer) IS NOT NULL
         AND dc.secondAnalogCost_productType IS NULL
            THEN 'SECOND_ANALOG_PRODUCT_TYPE_MISSING'

        WHEN dc.rn = 1
         AND dc.stream_eventname IN ('INSERT', 'MODIFY')
         AND TRY_CAST(dc.secondAnalogCost_cost AS integer) IS NOT NULL
         AND dc.secondAnalogCost_productType IS NOT NULL
            THEN 'SECOND_ANALOG_PRESENTE'

        ELSE 'NON_ULTIMO_RECORD_ATTIVO'
    END AS debug_secondAnalogCost

FROM delivery_cost_versions dc

ORDER BY
    dc.kinesis_dynamodb_ApproximateCreationDateTime DESC;