/*-----
Parametri da valorizzare:
<TARGET_IUN> = IUN da verificare

Lettura:
- Check 1: verifica che lo IUN sia nel perimetro notification ultimi 10 giorni.
- Check 2: verifica se lo IUN ha eventi REQUEST_REFUSED / NOTIFICATION_CANCELLED in timeline.
- Check 3: verifica le versioni delivery cost per IUN e recIndex.
- Check 4: confronto finale timeline vs delivery cost.
------*/
-- 1. Verifica che lo IUN rientri nel perimetro notification ultimi 10 giorni

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
      BETWEEN p.start_sent_date AND p.end_sent_date;

-- 2. Verifica se lo IUN ha eventi REQUEST_REFUSED o NOTIFICATION_CANCELLED in timeline

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
)

SELECT
    t.iun AS tl_iun,
    t.category AS tl_category,
    t.timelineElementId AS tl_timelineElementId,
    t.timestamp AS tl_timestamp,
    t.p_year,
    t.p_month,
    t.p_day,
    t.p_hour
FROM "cdc_analytics_database"."pn_timelines_json_view" t
CROSS JOIN params p
WHERE t.iun = p.target_iun
  AND t.category IN ('REQUEST_REFUSED', 'NOTIFICATION_CANCELLED')
  AND CAST(
        CAST(t.p_year AS varchar) ||
        LPAD(CAST(t.p_month AS varchar), 2, '0') ||
        LPAD(CAST(t.p_day AS varchar), 2, '0')
      AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
  AND t.timestamp IS NOT NULL
ORDER BY t.timestamp;


-- 3. Verifica tutte le versioni delivery cost per lo IUN e individua l'ultimo evento per recIndex

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
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
      AND CAST(
            CAST(dc.p_year AS varchar) ||
            LPAD(CAST(dc.p_month AS varchar), 2, '0') ||
            LPAD(CAST(dc.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
)

SELECT
    dynamodb_keys_pk AS dc_iun,
    TRY_CAST(dynamodb_keys_sk AS integer) AS dc_recIndex,
    TRY_CAST(isDeleted AS boolean) AS dc_isDeleted,
    stream_eventname,
    kinesis_dynamodb_ApproximateCreationDateTime,
    p_year,
    p_month,
    p_day,
    p_hour,
    rn,
    CASE
        WHEN rn = 1 AND stream_eventname = 'REMOVE' THEN 'ULTIMO_EVENTO_REMOVE'
        WHEN rn = 1 AND stream_eventname IN ('INSERT', 'MODIFY') THEN 'ULTIMO_EVENTO_ATTIVO'
        ELSE 'EVENTO_STORICO'
    END AS stato_record
FROM delivery_cost_versions
ORDER BY
    dc_recIndex,
    kinesis_dynamodb_ApproximateCreationDateTime DESC;


-- 4. Confronto finale: se timeline refused/cancelled, delivery cost deve avere isDeleted = true

WITH params AS (
    SELECT
        '<TARGET_IUN>' AS target_iun,
        CAST(date_format(date_add('day', -10, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key
),

timeline_flags AS (
    SELECT
        t.iun,
        MAX(
            CASE
                WHEN t.category IN ('REQUEST_REFUSED', 'NOTIFICATION_CANCELLED')
                THEN 1 ELSE 0
            END
        ) AS has_refused_or_cancelled,
        COUNT(
            CASE
                WHEN t.category IN ('REQUEST_REFUSED', 'NOTIFICATION_CANCELLED')
                THEN 1
            END
        ) AS tl_refused_cancelled_event_count,
        MAX(
            CASE
                WHEN t.category IN ('REQUEST_REFUSED', 'NOTIFICATION_CANCELLED')
                THEN t.timestamp
            END
        ) AS tl_last_refused_cancelled_timestamp
    FROM "cdc_analytics_database"."pn_timelines_json_view" t
    CROSS JOIN params p
    WHERE t.iun = p.target_iun
      AND CAST(
            CAST(t.p_year AS varchar) ||
            LPAD(CAST(t.p_month AS varchar), 2, '0') ||
            LPAD(CAST(t.p_day AS varchar), 2, '0')
          AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
      AND t.timestamp IS NOT NULL
    GROUP BY t.iun
),

delivery_cost_latest AS (
    SELECT *
    FROM (
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
          AND CAST(
                CAST(dc.p_year AS varchar) ||
                LPAD(CAST(dc.p_month AS varchar), 2, '0') ||
                LPAD(CAST(dc.p_day AS varchar), 2, '0')
              AS integer) BETWEEN p.start_partition_key AND p.max_partition_key
    )
    WHERE rn = 1
      AND stream_eventname IN ('INSERT', 'MODIFY')
)

SELECT
    dc.dynamodb_keys_pk AS dc_iun,
    TRY_CAST(dc.dynamodb_keys_sk AS integer) AS dc_recIndex,
    TRY_CAST(dc.isDeleted AS boolean) AS dc_isDeleted,

    tf.iun AS tl_iun,
    COALESCE(tf.has_refused_or_cancelled, 0) AS has_refused_or_cancelled,
    tf.tl_refused_cancelled_event_count,
    tf.tl_last_refused_cancelled_timestamp,

    CASE
        WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 1 THEN 'SI'
        ELSE 'NO'
    END AS evento_timeline_trovato,

    CASE
        WHEN dc.dynamodb_keys_pk IS NULL THEN 'NO'
        ELSE 'SI'
    END AS chiave_dc_trovata,

    CASE
        WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 1
             AND TRY_CAST(dc.isDeleted AS boolean) IS DISTINCT FROM true
            THEN 'MISMATCH_DELIVERY_COST'
        WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 0
             AND TRY_CAST(dc.isDeleted AS boolean) = true
            THEN 'MISMATCH_TIMELINE'
        ELSE 'NO_MISMATCH'
    END AS status_mismatch,

    CASE
        WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 1
             AND TRY_CAST(dc.isDeleted AS boolean) IS DISTINCT FROM true
            THEN 'KO'
        WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 0
             AND TRY_CAST(dc.isDeleted AS boolean) = true
            THEN 'KO'
        ELSE 'OK'
    END AS check_result

FROM delivery_cost_latest dc
LEFT JOIN timeline_flags tf
    ON tf.iun = dc.dynamodb_keys_pk
ORDER BY
    dc_recIndex;