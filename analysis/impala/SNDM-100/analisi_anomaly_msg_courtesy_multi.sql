WITH relevant_events AS (
  SELECT
    iun,
    category,
    timelineelementid,
    CAST(SUBSTR(`timestamp`, 1, 10) AS DATE) AS day,
    `timestamp` AS ts_raw,
    CAST(regexp_extract(timelineelementid, 'RECINDEX_([0-9]+)', 1) AS INT) AS recipient_index
  FROM send.silver_timeline
  WHERE category IN ('SEND_COURTESY_MESSAGE', 'SEND_ANALOG_DOMICILE')
    AND SUBSTR(notificationsentat, 1, 10) >= '2024-01-01'
),

courtesy_per_recipient AS (
  SELECT
    iun,
    recipient_index,
    MIN(day)    AS courtesy_day,
    MIN(ts_raw) AS ts_courtesy_raw
  FROM relevant_events
  WHERE category = 'SEND_COURTESY_MESSAGE'
    AND timelineelementid LIKE '%RECINDEX_%'
  GROUP BY iun, recipient_index
),

analog_per_recipient AS (
  SELECT
    iun,
    recipient_index,
    MAX(CASE WHEN timelineelementid LIKE '%ATTEMPT_0%' THEN day END)    AS analog_day,
    MAX(CASE WHEN timelineelementid LIKE '%ATTEMPT_0%' THEN ts_raw END) AS ts_analog_raw
  FROM relevant_events
  WHERE category = 'SEND_ANALOG_DOMICILE'
    AND timelineelementid LIKE '%RECINDEX_%'
  GROUP BY iun, recipient_index
),

latest_state_per_iun_recipient AS (
  SELECT
    a.iun,
    a.recipient_index,
    c.courtesy_day,
    c.ts_courtesy_raw,
    a.analog_day,
    a.ts_analog_raw
  FROM analog_per_recipient a
  LEFT JOIN courtesy_per_recipient c
    ON a.iun = c.iun
   AND a.recipient_index = c.recipient_index
),

gold_analytics AS (
  SELECT
    iun,
    tms_courtesy_message_sms,
    tms_courtesy_message_email,
    tms_courtesy_message_appio_sentmessage,
    recipients_size
  FROM send.gold_notification_analytics
),

enriched AS (
  SELECT
    s.iun,
    s.recipient_index,
    s.courtesy_day,
    s.analog_day,
    YEAR(s.analog_day)  AS analog_year,
    MONTH(s.analog_day) AS analog_month,
    g.tms_courtesy_message_sms,
    g.tms_courtesy_message_email,
    g.tms_courtesy_message_appio_sentmessage,
    g.recipients_size,
    CASE WHEN g.tms_courtesy_message_sms IS NOT NULL THEN TRUE ELSE FALSE END  AS flg_courtesy_sms,
    CASE WHEN g.tms_courtesy_message_email IS NOT NULL THEN TRUE ELSE FALSE END AS flg_courtesy_email,
    CASE WHEN g.tms_courtesy_message_appio_sentmessage IS NOT NULL THEN TRUE ELSE FALSE END AS flg_courtesy_appio,
    to_timestamp(replace(substr(s.ts_courtesy_raw, 1, 23), 'T', ' '), 'yyyy-MM-dd HH:mm:ss.SSS') AS ts_courtesy,
    to_timestamp(replace(substr(s.ts_analog_raw,    1, 23), 'T', ' '), 'yyyy-MM-dd HH:mm:ss.SSS') AS ts_analog
  FROM latest_state_per_iun_recipient s
  LEFT JOIN gold_analytics g
    ON s.iun = g.iun
),

calc AS (
  SELECT
    iun,
    recipient_index,
    ts_courtesy AS ts_send_courtesy,
    ts_analog   AS ts_send_analog,
    analog_year,
    analog_month,
    recipients_size,
    flg_courtesy_appio,
    flg_courtesy_email,
    flg_courtesy_sms,
    (unix_timestamp(ts_analog) - unix_timestamp(ts_courtesy)) / 3600.0 AS hours_diff_analog_courtesy,
    CASE
      WHEN ts_courtesy IS NULL OR ts_analog IS NULL THEN 'missing_courtesy_or_analog'
      WHEN ts_analog < ts_courtesy THEN 'before'
      ELSE 'after'
    END AS analog_vs_courtesy_timing,
    CASE
      WHEN ts_courtesy IS NULL OR ts_analog IS NULL THEN 'OK_MISSNG'
      WHEN ts_analog < ts_courtesy AND flg_courtesy_appio = TRUE THEN 'OK_ANOMALIA_DA_APPROFONDIRE'
      WHEN ts_analog < ts_courtesy AND (flg_courtesy_appio = FALSE OR flg_courtesy_appio IS NULL) THEN 'KO'
      WHEN ts_analog > ts_courtesy
           AND (unix_timestamp(ts_analog) - unix_timestamp(ts_courtesy)) / 3600.0 > 119 THEN 'OK_CARTACEO_INVIATO'
      WHEN ts_analog > ts_courtesy
           AND (unix_timestamp(ts_analog) - unix_timestamp(ts_courtesy)) / 3600.0 < 119 THEN 'KO'
      ELSE 'KO'
    END AS bug_status
  FROM enriched
)
SELECT
  iun,
  recipient_index,
  ts_send_courtesy,
  recipients_size,
  ts_send_analog,
  analog_year,
  analog_month,
  analog_vs_courtesy_timing,
  hours_diff_analog_courtesy,
  flg_courtesy_appio,
  flg_courtesy_email,
  flg_courtesy_sms,
  bug_status
FROM calc
WHERE bug_status = 'OK_ANOMALIA_DA_APPROFONDIRE'
  AND recipients_size > 1
  -- AND iun = 'AEHU-LWEN-QEKU-202505-T-1'
  -- AND flg_courtesy_appio = true
  -- AND CAST(ts_send_courtesy AS DATE) = CAST(ts_send_analog AS DATE)
ORDER BY iun, recipient_index;