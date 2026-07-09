WITH date_analysis AS (
    SELECT
        CAST(date_format(date_add('day', -7, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key,
        date_add('day', -7, current_date) AS start_sent_date,
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
        CROSS JOIN date_analysis p
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

notification_cost_ranked AS (
    SELECT
        nc.iun,
        TRY_CAST(nc.recipientIdx AS integer) AS recipientIdx,

        COALESCE(
            nc.creditorTaxId_noticeCode,
            nc.dynamodb_keys_creditorTaxId_noticeCode
        ) AS creditorTaxId_noticeCode,

        nc.stream_eventname,
        nc.kinesis_dynamodb_ApproximateCreationDateTime,

        ROW_NUMBER() OVER (
            PARTITION BY
                COALESCE(
                    nc.creditorTaxId_noticeCode,
                    nc.dynamodb_keys_creditorTaxId_noticeCode
                )
            ORDER BY nc.kinesis_dynamodb_ApproximateCreationDateTime DESC
        ) AS rn

    FROM "cdc_analytics_database"."pn_notifications_cost_json_view" nc
    CROSS JOIN date_analysis p
    WHERE CAST(
            CAST(nc.p_year AS varchar) ||
            LPAD(CAST(nc.p_month AS varchar), 2, '0') ||
            LPAD(CAST(nc.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
      AND COALESCE(
            nc.creditorTaxId_noticeCode,
            nc.dynamodb_keys_creditorTaxId_noticeCode
          ) IS NOT NULL
),

notification_cost_perimeter AS (
    SELECT DISTINCT
        iun,
        recipientIdx
    FROM notification_cost_ranked
    WHERE rn = 1
      AND stream_eventname IN ('INSERT', 'MODIFY')
      AND iun IS NOT NULL
      AND recipientIdx IS NOT NULL
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
        INNER JOIN notification_cost_perimeter ncp
            ON ncp.iun = dc.dynamodb_keys_pk
           AND ncp.recipientIdx = TRY_CAST(dc.dynamodb_keys_sk AS integer)
        CROSS JOIN date_analysis p
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
        INNER JOIN notification_cost_perimeter ncp
            ON ncp.iun = dc.dynamodb_keys_pk
           AND ncp.recipientIdx = TRY_CAST(dc.dynamodb_keys_sk AS integer)
        CROSS JOIN date_analysis p
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
    INNER JOIN notification_cost_perimeter ncp
        ON ncp.iun = nr.iun
       AND ncp.recipientIdx = nr.recIndex
    LEFT JOIN delivery_cost_last_event dc_last
        ON dc_last.dynamodb_keys_pk = nr.iun
       AND TRY_CAST(dc_last.dynamodb_keys_sk AS integer) = nr.recIndex
    LEFT JOIN delivery_cost_latest dc
        ON dc.dynamodb_keys_pk = nr.iun
       AND TRY_CAST(dc.dynamodb_keys_sk AS integer) = nr.recIndex
    WHERE dc_last.dynamodb_keys_pk IS NOT NULL
)

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
WHERE check_result = 'KO';