WITH params AS (
    SELECT
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
            TRY_CAST(SUBSTR(n.sentAt, 1, 10) AS date) AS sentAt_date,

            ROW_NUMBER() OVER (
                PARTITION BY n.iun
                ORDER BY n.kinesis_dynamodb_ApproximateCreationDateTime DESC
            ) AS rn

        FROM "cdc_analytics_database"."pn_notifications_json_view" n
        CROSS JOIN params p

        WHERE CAST(
                CAST(n.p_year AS varchar) ||
                LPAD(CAST(n.p_month AS varchar), 2, '0') ||
                LPAD(CAST(n.p_day AS varchar), 2, '0')
              AS integer) BETWEEN p.start_partition_key AND p.max_partition_key

          AND TRY_CAST(SUBSTR(n.sentAt, 1, 10) AS date)
              BETWEEN p.start_sent_date AND p.end_sent_date
    )
    WHERE rn = 1
),

notification_recipients AS (
    SELECT DISTINCT
        n.iun,
        CAST(rec_ordinality - 1 AS integer) AS recIndex
    FROM notification_latest n
    CROSS JOIN UNNEST(n.recipients)
        WITH ORDINALITY AS r(recipient, rec_ordinality)
),

timeline_events AS (
    SELECT
        t.iun,

        COALESCE(
            TRY_CAST(t.details_recIndex AS integer),
            TRY_CAST(REGEXP_EXTRACT(t.timelineElementId, 'RECINDEX_([0-9]+)', 1) AS integer)
        ) AS recIndex,

        t.category,
        t.timelineElementId,
        TRY_CAST(t.details_sentAttemptMade AS integer) AS sentAttemptMade,

        TRY_CAST(t.details_analogCost AS integer) AS analogCost_value,
        TRY_CAST(t.details_notificationCost AS integer) AS notificationCost_value,

        t.timestamp

    FROM "cdc_analytics_database"."pn_timelines_json_view" t
    INNER JOIN notification_recipients nr
        ON nr.iun = t.iun
       AND nr.recIndex = COALESCE(
            TRY_CAST(t.details_recIndex AS integer),
            TRY_CAST(REGEXP_EXTRACT(t.timelineElementId, 'RECINDEX_([0-9]+)', 1) AS integer)
       )

    CROSS JOIN params p

    WHERE CAST(
            CAST(t.p_year AS varchar) ||
            LPAD(CAST(t.p_month AS varchar), 2, '0') ||
            LPAD(CAST(t.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key

      AND t.timestamp IS NOT NULL
),

timeline_cost_events AS (
    SELECT
        iun,
        recIndex,
        category,
        timelineElementId,
        sentAttemptMade,
        analogCost_value,
        notificationCost_value,
        timestamp,

        CASE
            WHEN category = 'SEND_ANALOG_DOMICILE'
             AND sentAttemptMade = 0
                THEN 'FIRST_ANALOG'

            WHEN category = 'SEND_ANALOG_DOMICILE'
             AND sentAttemptMade = 1
                THEN 'SECOND_ANALOG'

            WHEN category = 'SEND_SIMPLE_REGISTERED_LETTER'
              OR timelineElementId LIKE '%SEND_SIMPLE_REGISTERED_LETTER%'
                THEN 'SIMPLE_REGISTERED_LETTER'

            ELSE NULL
        END AS expected_cost_type
    FROM timeline_events
    WHERE category IN (
        'SEND_ANALOG_DOMICILE',
        'SEND_SIMPLE_REGISTERED_LETTER'
    )
),

timeline_cost_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                iun,
                recIndex,
                expected_cost_type
            ORDER BY timestamp DESC
        ) AS rn
    FROM timeline_cost_events
    WHERE expected_cost_type IS NOT NULL
),

timeline_cost_expected AS (
    SELECT
        iun,
        recIndex,

        MAX(CASE WHEN expected_cost_type = 'FIRST_ANALOG' THEN 1 ELSE 0 END)
            AS expected_firstAnalogCost,

        MAX(CASE WHEN expected_cost_type = 'FIRST_ANALOG' THEN analogCost_value END)
            AS expected_firstAnalogCost_value,

        MAX(CASE WHEN expected_cost_type = 'SECOND_ANALOG' THEN 1 ELSE 0 END)
            AS expected_secondAnalogCost,

        MAX(CASE WHEN expected_cost_type = 'SECOND_ANALOG' THEN analogCost_value END)
            AS expected_secondAnalogCost_value,

        MAX(CASE WHEN expected_cost_type = 'SIMPLE_REGISTERED_LETTER' THEN 1 ELSE 0 END)
            AS expected_simpleRegisteredLetterCost,

        MAX(CASE WHEN expected_cost_type = 'SIMPLE_REGISTERED_LETTER' THEN notificationCost_value END)
            AS expected_simpleRegisteredLetterCost_value,

        COUNT(*) AS timeline_event_count,
        MAX(timestamp) AS timeline_last_timestamp

    FROM timeline_cost_ranked
    WHERE rn = 1
    GROUP BY
        iun,
        recIndex
),

delivery_cost_ranked AS (
    SELECT
        dc.*,

        ROW_NUMBER() OVER (
            PARTITION BY
                dc.dynamodb_keys_pk,
                dc.dynamodb_keys_sk
            ORDER BY dc.kinesis_dynamodb_ApproximateCreationDateTime DESC
        ) AS rn

    FROM "cdc_analytics_database"."pn_notification_delivery_cost_json_view" dc
    INNER JOIN notification_recipients nr
        ON nr.iun = dc.dynamodb_keys_pk
       AND nr.recIndex = TRY_CAST(dc.dynamodb_keys_sk AS integer)

    CROSS JOIN params p

    WHERE CAST(
            CAST(dc.p_year AS varchar) ||
            LPAD(CAST(dc.p_month AS varchar), 2, '0') ||
            LPAD(CAST(dc.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
),

delivery_cost_latest AS (
    SELECT *
    FROM delivery_cost_ranked
    WHERE rn = 1
      AND stream_eventname IN ('INSERT', 'MODIFY')
),

check_detail_status AS (
    SELECT
        nr.iun,
        nr.recIndex,

        COALESCE(tl.expected_firstAnalogCost, 0) AS expected_firstAnalogCost,
        tl.expected_firstAnalogCost_value,

        COALESCE(tl.expected_secondAnalogCost, 0) AS expected_secondAnalogCost,
        tl.expected_secondAnalogCost_value,

        COALESCE(tl.expected_simpleRegisteredLetterCost, 0) AS expected_simpleRegisteredLetterCost,
        tl.expected_simpleRegisteredLetterCost_value,

        tl.timeline_event_count,
        tl.timeline_last_timestamp,

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

        CASE
            WHEN dc.dynamodb_keys_pk IS NULL
                THEN 'DELIVERY_COST_MISSING'

            WHEN TRY_CAST(dc.baseCost_sendFee AS integer) IS NULL
                THEN 'BASE_SEND_FEE_MISSING'

            WHEN TRY_CAST(dc.baseCost_paFee AS integer) IS NULL
                THEN 'BASE_PA_FEE_MISSING'

            WHEN COALESCE(tl.expected_firstAnalogCost, 0) = 1
             AND TRY_CAST(dc.firstAnalogCost_cost AS integer) IS NULL
                THEN 'FIRST_ANALOG_COST_MISSING'

            WHEN COALESCE(tl.expected_firstAnalogCost, 0) = 1
             AND TRY_CAST(dc.firstAnalogCost_cost AS integer) IS NOT NULL
             AND dc.firstAnalogCost_productType IS NULL
                THEN 'FIRST_ANALOG_PRODUCT_TYPE_MISSING'

            WHEN tl.expected_firstAnalogCost_value IS NOT NULL
             AND TRY_CAST(dc.firstAnalogCost_cost AS integer) IS NOT NULL
             AND tl.expected_firstAnalogCost_value <> TRY_CAST(dc.firstAnalogCost_cost AS integer)
                THEN 'FIRST_ANALOG_COST_VALUE_MISMATCH'

            WHEN COALESCE(tl.expected_secondAnalogCost, 0) = 1
             AND TRY_CAST(dc.secondAnalogCost_cost AS integer) IS NULL
                THEN 'SECOND_ANALOG_COST_MISSING'

            WHEN COALESCE(tl.expected_secondAnalogCost, 0) = 1
             AND TRY_CAST(dc.secondAnalogCost_cost AS integer) IS NOT NULL
             AND dc.secondAnalogCost_productType IS NULL
                THEN 'SECOND_ANALOG_PRODUCT_TYPE_MISSING'

            WHEN tl.expected_secondAnalogCost_value IS NOT NULL
             AND TRY_CAST(dc.secondAnalogCost_cost AS integer) IS NOT NULL
             AND tl.expected_secondAnalogCost_value <> TRY_CAST(dc.secondAnalogCost_cost AS integer)
                THEN 'SECOND_ANALOG_COST_VALUE_MISMATCH'

            WHEN COALESCE(tl.expected_simpleRegisteredLetterCost, 0) = 1
             AND TRY_CAST(dc.simpleRegisteredLetterCost_cost AS integer) IS NULL
                THEN 'SIMPLE_RL_COST_MISSING'

            WHEN COALESCE(tl.expected_simpleRegisteredLetterCost, 0) = 1
             AND TRY_CAST(dc.simpleRegisteredLetterCost_cost AS integer) IS NOT NULL
             AND dc.simpleRegisteredLetterCost_productType IS NULL
                THEN 'SIMPLE_RL_PRODUCT_TYPE_MISSING'

            WHEN tl.expected_simpleRegisteredLetterCost_value IS NOT NULL
             AND TRY_CAST(dc.simpleRegisteredLetterCost_cost AS integer) IS NOT NULL
             AND tl.expected_simpleRegisteredLetterCost_value <> TRY_CAST(dc.simpleRegisteredLetterCost_cost AS integer)
                THEN 'SIMPLE_RL_COST_VALUE_MISMATCH'

            WHEN COALESCE(tl.expected_simpleRegisteredLetterCost, 0) = 1
             AND dc.simpleRegisteredLetterCost_productType IS NOT NULL
             AND dc.simpleRegisteredLetterCost_productType <> 'SEND_SIMPLE_REGISTERED_LETTER'
                THEN 'SIMPLE_RL_PRODUCT_TYPE_MISMATCH'

            ELSE 'NO_MISMATCH'
        END AS status_mismatch

    FROM notification_recipients nr

    LEFT JOIN timeline_cost_expected tl
        ON tl.iun = nr.iun
       AND tl.recIndex = nr.recIndex

    LEFT JOIN delivery_cost_latest dc
        ON dc.dynamodb_keys_pk = nr.iun
       AND TRY_CAST(dc.dynamodb_keys_sk AS integer) = nr.recIndex
),

check_detail AS (
    SELECT
        *,

        CASE
            WHEN status_mismatch <> 'NO_MISMATCH' THEN 'KO'
            ELSE 'OK'
        END AS check_result,

        CASE
            WHEN status_mismatch = 'DELIVERY_COST_MISSING' THEN 1
            WHEN status_mismatch = 'BASE_SEND_FEE_MISSING' THEN 2
            WHEN status_mismatch = 'BASE_PA_FEE_MISSING' THEN 3
            WHEN status_mismatch = 'FIRST_ANALOG_COST_MISSING' THEN 4
            WHEN status_mismatch = 'FIRST_ANALOG_PRODUCT_TYPE_MISSING' THEN 5
            WHEN status_mismatch = 'FIRST_ANALOG_COST_VALUE_MISMATCH' THEN 6
            WHEN status_mismatch = 'SECOND_ANALOG_COST_MISSING' THEN 7
            WHEN status_mismatch = 'SECOND_ANALOG_PRODUCT_TYPE_MISSING' THEN 8
            WHEN status_mismatch = 'SECOND_ANALOG_COST_VALUE_MISMATCH' THEN 9
            WHEN status_mismatch = 'SIMPLE_RL_COST_MISSING' THEN 10
            WHEN status_mismatch = 'SIMPLE_RL_PRODUCT_TYPE_MISSING' THEN 11
            WHEN status_mismatch = 'SIMPLE_RL_COST_VALUE_MISMATCH' THEN 12
            WHEN status_mismatch = 'SIMPLE_RL_PRODUCT_TYPE_MISMATCH' THEN 13
            ELSE 14
        END AS check_order

    FROM check_detail_status
)

/* GROUP BY

SELECT
    check_result,
    status_mismatch,
    COUNT(
        DISTINCT CONCAT(
            iun,
            '##',
            CAST(recIndex AS varchar)
        )
    ) AS num_record
FROM check_detail
WHERE check_result = 'KO'
GROUP BY
    check_result,
    status_mismatch
ORDER BY
    MIN(check_order),
    num_record DESC;
*/


/* SELECT COMPLETA */

SELECT
    iun,
    recIndex,

    expected_firstAnalogCost,
    expected_firstAnalogCost_value,

    expected_secondAnalogCost,
    expected_secondAnalogCost_value,

    expected_simpleRegisteredLetterCost,
    expected_simpleRegisteredLetterCost_value,

    timeline_event_count,
    timeline_last_timestamp,

    baseCost_sendFee,
    baseCost_paFee,

    firstAnalogCost_cost,
    firstAnalogCost_productType,

    secondAnalogCost_cost,
    secondAnalogCost_productType,

    simpleRegisteredLetterCost_cost,
    simpleRegisteredLetterCost_productType,

    stream_eventname,
    kinesis_dynamodb_ApproximateCreationDateTime,

    check_result,
    status_mismatch
FROM check_detail
WHERE check_result = 'KO'
ORDER BY
    check_order,
    iun,
    recIndex;