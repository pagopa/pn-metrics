WITH date_analysis AS (
    SELECT
        CAST(date_format(date_add('day', -7, current_date), '%Y%m%d') AS integer) AS start_partition_key,
        CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS max_partition_key,
        date_add('day', -7, current_date) AS start_sent_date,
        date_add('day', -1, current_date) AS end_sent_date
),

notification_perimeter AS (
    SELECT DISTINCT
        n.iun
    FROM "cdc_analytics_database"."pn_notifications_json_view" n
    CROSS JOIN date_analysis df
    WHERE CAST(
            CAST(n.p_year AS varchar) ||
            LPAD(CAST(n.p_month AS varchar), 2, '0') ||
            LPAD(CAST(n.p_day AS varchar), 2, '0')
          AS integer) BETWEEN df.start_partition_key AND df.max_partition_key
      AND TRY_CAST(SUBSTR(n.sentAt, 1, 10) AS date)
          BETWEEN df.start_sent_date AND df.end_sent_date
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
    INNER JOIN notification_perimeter np
        ON np.iun = t.iun
    CROSS JOIN date_analysis df
    WHERE CAST(
            CAST(t.p_year AS varchar) ||
            LPAD(CAST(t.p_month AS varchar), 2, '0') ||
            LPAD(CAST(t.p_day AS varchar), 2, '0')
          AS integer) BETWEEN df.start_partition_key AND df.max_partition_key
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
        INNER JOIN notification_perimeter np
            ON np.iun = dc.dynamodb_keys_pk
        CROSS JOIN date_analysis df
        WHERE CAST(
                CAST(dc.p_year AS varchar) ||
                LPAD(CAST(dc.p_month AS varchar), 2, '0') ||
                LPAD(CAST(dc.p_day AS varchar), 2, '0')
              AS integer) BETWEEN df.start_partition_key AND df.max_partition_key
    )
    WHERE rn = 1
      AND stream_eventname IN ('INSERT', 'MODIFY')
),

check_detail AS (
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
            WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 0
                 AND dc.isDeleted = true
                THEN 'MISMATCH_TIMELINE'
        
            WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 1
                 AND dc.isDeleted IS NULL
                THEN 'MISMATCH_DELIVERY_COST'
        
            WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 1
                 AND dc.isDeleted = true
                THEN 'NO_MISMATCH_ISEDELETED'
        
            WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 0
                 AND dc.isDeleted IS NULL
                THEN 'NO_MISMATCH'
        END AS status_mismatch,

        CASE
            WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 0
                 AND dc.isDeleted = true
                THEN 'KO'
        
            WHEN COALESCE(tf.has_refused_or_cancelled, 0) = 1
                 AND dc.isDeleted IS NULL
                THEN 'KO'
        
            ELSE 'OK'
        END AS check_result
    FROM delivery_cost_latest dc
    LEFT JOIN timeline_flags tf
        ON tf.iun = dc.dynamodb_keys_pk
)

SELECT
    dc_iun,
    dc_recIndex,
    dc_isDeleted,
    tl_iun,
    evento_timeline_trovato,
    has_refused_or_cancelled,
    tl_refused_cancelled_event_count,
    tl_last_refused_cancelled_timestamp,
    chiave_dc_trovata,
    check_result,
    status_mismatch
FROM check_detail
WHERE check_result = 'KO'; 