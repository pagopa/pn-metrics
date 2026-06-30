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
    SELECT
        n.iun,
        CAST(rec_ordinality - 1 AS integer) AS recIndex,
        recipient.recipientId AS recipientInternalId,
        n.notificationFeePolicy,
        n.pagoPaIntMode,
        TRY_CAST(n.vat AS integer) AS vat,
        TRY_CAST(n.paFee AS integer) AS paFee,
        n.senderPaId,
        n.senderTaxId
    FROM notification_latest n
    CROSS JOIN UNNEST(n.recipients) WITH ORDINALITY AS r(recipient, rec_ordinality)
),

delivery_cost_last_event AS (
    SELECT *
    FROM (
        SELECT
            dc.dynamodb_keys_pk,
            dc.dynamodb_keys_sk,
            dc.stream_eventname,
            ROW_NUMBER() OVER (
                PARTITION BY dc.dynamodb_keys_pk, dc.dynamodb_keys_sk
                ORDER BY dc.kinesis_dynamodb_ApproximateCreationDateTime DESC
            ) AS rn
        FROM "cdc_analytics_database"."pn_notification_delivery_cost_json_view" dc
        INNER JOIN (
            SELECT DISTINCT iun, recIndex
            FROM notification_recipients
        ) nr
            ON nr.iun = dc.dynamodb_keys_pk
           AND nr.recIndex = TRY_CAST(dc.dynamodb_keys_sk AS integer)
        CROSS JOIN params p
        WHERE CAST(
                CAST(dc.p_year AS varchar) ||
                LPAD(CAST(dc.p_month AS varchar), 2, '0') ||
                LPAD(CAST(dc.p_day AS varchar), 2, '0')
              AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
    )
    WHERE rn = 1
),

delivery_cost_latest AS (
    SELECT *
    FROM (
        SELECT
            dc.*,
            ROW_NUMBER() OVER (
                PARTITION BY dc.dynamodb_keys_pk, dc.dynamodb_keys_sk
                ORDER BY dc.kinesis_dynamodb_ApproximateCreationDateTime DESC
            ) AS rn
        FROM "cdc_analytics_database"."pn_notification_delivery_cost_json_view" dc
        INNER JOIN (
            SELECT DISTINCT iun, recIndex
            FROM notification_recipients
        ) nr
            ON nr.iun = dc.dynamodb_keys_pk
           AND nr.recIndex = TRY_CAST(dc.dynamodb_keys_sk AS integer)
        CROSS JOIN params p
        WHERE CAST(
                CAST(dc.p_year AS varchar) ||
                LPAD(CAST(dc.p_month AS varchar), 2, '0') ||
                LPAD(CAST(dc.p_day AS varchar), 2, '0')
              AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
    )
    WHERE rn = 1
      AND stream_eventname IN ('INSERT', 'MODIFY')
),

check_detail AS (
    SELECT
        nr.iun AS n_iun,
        nr.recIndex AS n_recIndex,
        nr.recipientInternalId AS n_recipientInternalId,
        nr.notificationFeePolicy AS n_notificationFeePolicy,
        nr.pagoPaIntMode AS n_pagoPaIntMode,
        nr.vat AS n_vat,
        nr.paFee AS n_paFee,
        nr.senderPaId AS n_senderPaId,
        nr.senderTaxId AS n_senderTaxId,

        dc.dynamodb_keys_pk AS dc_iun,
        TRY_CAST(dc.dynamodb_keys_sk AS integer) AS dc_recIndex,
        dc.recipientInternalId AS dc_recipientInternalId,
        dc.notificationFeePolicy AS dc_notificationFeePolicy,
        dc.pagoPaIntMode AS dc_pagoPaIntMode,
        TRY_CAST(dc.vat AS integer) AS dc_vat,
        TRY_CAST(dc.baseCost_paFee AS integer) AS dc_baseCost_paFee,
        dc.senderPaId AS dc_senderPaId,
        dc.senderTaxId AS dc_senderTaxId,

        CASE
            WHEN dc.dynamodb_keys_pk IS NULL THEN 'KO'
            WHEN dc.notificationFeePolicy IS DISTINCT FROM nr.notificationFeePolicy THEN 'KO'
            WHEN dc.pagoPaIntMode IS DISTINCT FROM nr.pagoPaIntMode THEN 'KO'
            WHEN TRY_CAST(dc.vat AS integer) IS DISTINCT FROM nr.vat THEN 'KO'
            WHEN TRY_CAST(dc.baseCost_paFee AS integer) IS DISTINCT FROM nr.paFee THEN 'KO'
            WHEN dc.senderPaId IS DISTINCT FROM nr.senderPaId THEN 'KO'
            WHEN dc.senderTaxId IS DISTINCT FROM nr.senderTaxId THEN 'KO'
            WHEN dc.recipientInternalId IS DISTINCT FROM nr.recipientInternalId THEN 'KO'
            ELSE 'OK'
        END AS check_result,

        CASE
            WHEN dc.dynamodb_keys_pk IS NULL THEN 'NO'
            ELSE 'SI'
        END AS chiave_dc_trovato,

        CASE
            WHEN dc.dynamodb_keys_pk IS NULL THEN 'MISMATCH_DELIVERY_COST'
            WHEN dc.notificationFeePolicy IS DISTINCT FROM nr.notificationFeePolicy THEN 'FEE_POLICY'
            WHEN dc.pagoPaIntMode IS DISTINCT FROM nr.pagoPaIntMode THEN 'PAGOPA_MODE'
            WHEN TRY_CAST(dc.vat AS integer) IS DISTINCT FROM nr.vat THEN 'VAT'
            WHEN TRY_CAST(dc.baseCost_paFee AS integer) IS DISTINCT FROM nr.paFee THEN 'PA_FEE'
            WHEN dc.senderPaId IS DISTINCT FROM nr.senderPaId THEN 'SENDER_PA_ID'
            WHEN dc.senderTaxId IS DISTINCT FROM nr.senderTaxId THEN 'SENDER_TAX_ID'
            WHEN dc.recipientInternalId IS DISTINCT FROM nr.recipientInternalId THEN 'RECIPIENT_ID'
            ELSE 'NO_MISMATCH'
        END AS status_mismatch,

        CASE
            WHEN dc.dynamodb_keys_pk IS NULL THEN 1
            WHEN dc.notificationFeePolicy IS DISTINCT FROM nr.notificationFeePolicy THEN 2
            WHEN dc.pagoPaIntMode IS DISTINCT FROM nr.pagoPaIntMode THEN 3
            WHEN TRY_CAST(dc.vat AS integer) IS DISTINCT FROM nr.vat THEN 4
            WHEN TRY_CAST(dc.baseCost_paFee AS integer) IS DISTINCT FROM nr.paFee THEN 5
            WHEN dc.senderPaId IS DISTINCT FROM nr.senderPaId THEN 6
            WHEN dc.senderTaxId IS DISTINCT FROM nr.senderTaxId THEN 7
            WHEN dc.recipientInternalId IS DISTINCT FROM nr.recipientInternalId THEN 8
            ELSE 9
        END AS check_order
    FROM notification_recipients nr
    LEFT JOIN delivery_cost_last_event dc_last
        ON dc_last.dynamodb_keys_pk = nr.iun
       AND TRY_CAST(dc_last.dynamodb_keys_sk AS integer) = nr.recIndex
    LEFT JOIN delivery_cost_latest dc
        ON dc.dynamodb_keys_pk = nr.iun
       AND TRY_CAST(dc.dynamodb_keys_sk AS integer) = nr.recIndex
    WHERE dc_last.dynamodb_keys_pk IS NOT NULL
)

/* GROUP completa 

SELECT
    check_result,
    chiave_dc_trovato,
    status_mismatch,
    COUNT(*) AS num_record
FROM check_detail
WHERE check_result = 'KO'
GROUP BY
    check_result,
    chiave_dc_trovato,
    status_mismatch
ORDER BY
    num_record DESC;*/


/* SELECT completa */

SELECT 
    n_iun, 
    n_recIndex, 
    n_recipientInternalId,
    n_notificationFeePolicy,
    n_pagoPaIntMode,
    n_vat,
    n_paFee,
    n_senderPaId,
    n_senderTaxId,

    dc_iun,
    dc_recIndex,
    dc_recipientInternalId,
    dc_notificationFeePolicy,
    dc_pagoPaIntMode,
    dc_vat,
    dc_baseCost_paFee,
    dc_senderPaId,
    dc_senderTaxId,

    check_result,
    chiave_dc_trovato,
    status_mismatch 
FROM check_detail 
WHERE check_result = 'KO'
ORDER BY
    check_order,
    n_iun,
    n_recIndex;
