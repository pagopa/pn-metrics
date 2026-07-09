WITH date_analysis AS (
    SELECT
        CAST(date_format(date_add('day', -7, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key,
        date_add('day', -1, current_date) AS start_sent_date,
        date_add('day', -7, current_date) AS end_sent_date
),

notification_cost_ranked AS (
    SELECT
        nc.iun,
        TRY_CAST(nc.recipientIdx AS integer) AS recipientIdx,
        nc.recipientType,

        COALESCE(
            nc.creditorTaxId_noticeCode,
            nc.dynamodb_keys_creditorTaxId_noticeCode
        ) AS creditorTaxId_noticeCode,

        SPLIT_PART(
            COALESCE(
                nc.creditorTaxId_noticeCode,
                nc.dynamodb_keys_creditorTaxId_noticeCode
            ),
            '##',
            1
        ) AS creditorTaxId,

        SPLIT_PART(
            COALESCE(
                nc.creditorTaxId_noticeCode,
                nc.dynamodb_keys_creditorTaxId_noticeCode
            ),
            '##',
            2
        ) AS noticeCode,

        nc.stream_eventname,
        nc.kinesis_dynamodb_ApproximateCreationDateTime,

        ROW_NUMBER() OVER (
            PARTITION BY
                COALESCE(
                    nc.creditorTaxId_noticeCode,
                    nc.dynamodb_keys_creditorTaxId_noticeCode
                )
            ORDER BY
                nc.kinesis_dynamodb_ApproximateCreationDateTime DESC
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
        ncr.iun,
        ncr.recipientIdx,
        ncr.recipientType,
        ncr.creditorTaxId_noticeCode,
        ncr.creditorTaxId,
        ncr.noticeCode
    FROM notification_cost_ranked ncr
    WHERE ncr.rn = 1
      AND ncr.stream_eventname IN ('INSERT', 'MODIFY')
),

notification_perimeter AS (
    SELECT DISTINCT
        n.iun
    FROM "cdc_analytics_database"."pn_notifications_json_view" n
    CROSS JOIN date_analysis p
    INNER JOIN notification_cost_perimeter nc
        ON nc.iun = n.iun
    WHERE CAST(
            CAST(n.p_year AS varchar) ||
            LPAD(CAST(n.p_month AS varchar), 2, '0') ||
            LPAD(CAST(n.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
      AND TRY_CAST(SUBSTR(n.sentAt, 1, 10) AS date)
          BETWEEN p.start_sent_date AND p.end_sent_date
),

payment_info_ranked AS (
    SELECT
        p.dynamodb_keys_pk,
        p.iun,
        TRY_CAST(p.recIndex AS integer) AS recIndex,
        p.applyCost,
        p.stream_eventname,
        p.kinesis_dynamodb_ApproximateCreationDateTime,

        ROW_NUMBER() OVER (
            PARTITION BY p.dynamodb_keys_pk
            ORDER BY p.kinesis_dynamodb_ApproximateCreationDateTime DESC
        ) AS rn

    FROM "cdc_analytics_database"."pn_payment_info_json_view" p
    INNER JOIN (
        SELECT DISTINCT creditorTaxId_noticeCode
        FROM notification_cost_perimeter
    ) nc
        ON nc.creditorTaxId_noticeCode = p.dynamodb_keys_pk
    CROSS JOIN date_analysis par
    WHERE CAST(
            CAST(p.p_year AS varchar) ||
            LPAD(CAST(p.p_month AS varchar), 2, '0') ||
            LPAD(CAST(p.p_day AS varchar), 2, '0')
          AS integer) BETWEEN par.start_partition_key AND par.max_partition_key
),

payment_info_perimeter AS (
    SELECT
        dynamodb_keys_pk,
        iun,
        recIndex,
        applyCost
    FROM payment_info_ranked
    WHERE rn = 1
      AND stream_eventname IN ('INSERT', 'MODIFY')
),

check_detail AS (
    SELECT
        nc.iun AS nc_iun,
        nc.recipientIdx AS nc_recipientIdx,
        nc.recipientType AS nc_recipientType,
        nc.creditorTaxId_noticeCode AS nc_creditorTaxId_noticeCode,
        nc.creditorTaxId AS nc_creditorTaxId,
        nc.noticeCode AS nc_noticeCode,

        pi.dynamodb_keys_pk AS pi_dynamodb_keys_pk,
        pi.iun AS pi_iun,
        pi.recIndex AS pi_recIndex,
        pi.applyCost AS pi_applyCost,

        CASE
            WHEN pi.dynamodb_keys_pk IS NULL THEN 'KO'
            WHEN pi.iun <> nc.iun THEN 'KO'
            WHEN pi.recIndex <> nc.recipientIdx THEN 'KO'
            ELSE 'OK'
        END AS check_result,

        CASE
            WHEN pi.dynamodb_keys_pk IS NULL THEN 'NO'
            ELSE 'SI'
        END AS chiave_trovata,

        CASE
            WHEN pi.dynamodb_keys_pk IS NULL THEN 'PAYMENT_ASSENTE'
            WHEN pi.iun <> nc.iun THEN 'MISMATCH_IUN'
            WHEN pi.recIndex <> nc.recipientIdx THEN 'MISMATCH_RECINDEX'
            ELSE 'NO_MISMATCH'
        END AS status_mismatch,

        CASE
            WHEN pi.dynamodb_keys_pk IS NULL THEN 1
            WHEN pi.iun <> nc.iun THEN 2
            WHEN pi.recIndex <> nc.recipientIdx THEN 3
            ELSE 4
        END AS check_order

    FROM notification_cost_perimeter nc
    INNER JOIN notification_perimeter np
        ON np.iun = nc.iun
    LEFT JOIN payment_info_perimeter pi
        ON pi.dynamodb_keys_pk = nc.creditorTaxId_noticeCode
)

SELECT
    nc_iun,
    nc_recipientIdx,
    nc_recipientType,
    nc_creditorTaxId_noticeCode,
    nc_creditorTaxId,
    nc_noticeCode,

    pi_dynamodb_keys_pk,
    pi_iun,
    pi_recIndex,
    pi_applyCost,

    check_result,
    chiave_trovata,
    status_mismatch
FROM check_detail
WHERE check_result = 'KO';