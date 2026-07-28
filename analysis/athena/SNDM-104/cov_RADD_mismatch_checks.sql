-- Check RADD coverage data for a specific cap

WITH dw AS (
  SELECT
    current_date AS today,
    date_add('day', -60, current_date) AS from_day,
    CAST(date_format(date_add('day', -60, current_date), '%Y%m%d') AS integer) AS from_int,
    CAST(date_format(current_date, '%Y%m%d') AS integer) AS to_int
)
SELECT
  c.cap,
  c.endValidity,
  c.startValidity
FROM pn_radd_coverage_json_view c
CROSS JOIN dw
WHERE c.cap = '33100'
AND CAST(c.p_year || LPAD(c.p_month, 2, '0') || LPAD(c.p_day, 2, '0') AS integer)
        BETWEEN dw.from_int AND dw.to_int
ORDER BY startValidity DESC

-- Check timeline data for notifications sent to the specific cap

SELECT *
FROM "cdc_analytics_database"."pn_timelines_json_view" t
WHERE CAST(t.p_year || LPAD(t.p_month, 2, '0') || LPAD(t.p_day, 2, '0') AS integer)
      BETWEEN CAST(date_format(date_add('day', -60, current_date), '%Y%m%d') AS integer)
          AND CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer)
  AND t.category IN ('SEND_ANALOG_DOMICILE', 'AAR_CREATION_REQUEST')
  AND t.iun IN (
    'GJTR-XKGZ-QAQJ-202602-N-1'
  )
ORDER BY t.iun, t.details_recindex, t."timestamp";


-- Check if there are notifications sent to the specific cap with a delay of more than 30 minutes from their creation time
WITH params AS (
  SELECT
    CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer) AS start_part_int,
    CAST(date_format(current_date, '%Y%m%d') AS integer) AS today_int
),

analog_base AS (
  SELECT
    t.iun,
    t.details_recindex AS recindex,
    TRY_CAST(t.details_sentattemptmade AS integer) AS attempt,
    t.details_physicaladdress_zip AS cap,
    t.notificationSentAt,
    from_iso8601_timestamp(t.notificationSentAt) AS notification_created_ts,
    t."timestamp" AS send_analog_event_ts,
    from_iso8601_timestamp(t."timestamp") AS analog_send_ts,
    current_timestamp AS now_ts,
    date_diff(
      'minute',
      from_iso8601_timestamp(t.notificationSentAt),
      current_timestamp
    ) AS minutes_from_notification_creation
  FROM pn_timelines_json_view t
  CROSS JOIN params p
  WHERE t.category = 'SEND_ANALOG_DOMICILE'
    AND t.notificationSentAt IS NOT NULL
    AND TRY_CAST(t.details_sentattemptmade AS integer) IN (0, 1)
    AND CAST(t.p_year || LPAD(t.p_month, 2, '0') || LPAD(t.p_day, 2, '0') AS integer)
        BETWEEN p.start_part_int AND p.today_int
)

SELECT
  iun,
  recindex,
  attempt,
  cap,
  notification_created_ts,
  analog_send_ts,
  minutes_from_notification_creation,
  CASE
    WHEN notification_created_ts <= current_timestamp - INTERVAL '30' MINUTE
      THEN 'ENTRA_NEL_MONITORAGGIO'
    ELSE 'ESCLUSA_PER_FINESTRA_30_MIN'
  END AS esito_filtro_30_min
FROM analog_base
ORDER BY notification_created_ts DESC
LIMIT 50;

-- Check if there are notifications sent to the specific cap with a delay of more than 30 minutes from their creation time 

WITH analog_notifications AS (
  SELECT
    t.iun,
    t.details_recindex AS recindex,
    TRY_CAST(t.details_sentattemptmade AS integer) AS attempt,
    TRY_CAST(t.details_numberofpages AS integer) AS pages,
    t.details_physicaladdress_zip AS cap,
    t.details_physicaladdress_foreignstate AS foreign_state,
    from_iso8601_timestamp(t."timestamp") AS analog_send_ts,
    from_iso8601_timestamp(t.notificationSentAt) AS notification_created_ts,
    current_timestamp AS now_ts,
    date_diff(
      'minute',
      from_iso8601_timestamp(t.notificationSentAt),
      current_timestamp
    ) AS minutes_from_notification_creation
  FROM pn_timelines_json_view t
  WHERE t.category = 'SEND_ANALOG_DOMICILE'
    AND t.iun = 'UQPZ-YWUZ-DQLA-202605-L-1'
    AND t.notificationSentAt IS NOT NULL
    AND TRY_CAST(t.details_sentattemptmade AS integer) IN (0, 1)
    AND CAST(t.p_year || LPAD(t.p_month, 2, '0') || LPAD(t.p_day, 2, '0') AS integer)
        BETWEEN CAST(date_format(date_add('day', -1, current_date), '%Y%m%d') AS integer)
            AND CAST(date_format(current_date, '%Y%m%d') AS integer)
    AND from_iso8601_timestamp(t.notificationSentAt) <= current_timestamp - INTERVAL '30' MINUTE
)

SELECT *
FROM analog_notifications
ORDER BY notification_created_ts DESC
LIMIT 50;