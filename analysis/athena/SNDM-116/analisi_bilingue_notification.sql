-- Distribuzione notifiche bilingue
-- Conteggio delle notifiche con IT e una seconda lingua, aggregate per lingua diversa da IT.

SELECT
  element_at(
    filter(
      transform(languages, x -> x.lang),
      lang -> lang <> 'IT'
    ),
    1
  ) AS altra_lingua,
  COUNT(*) AS numero_notifiche
FROM "cdc_analytics_database"."pn_notifications_json_view"
WHERE iun IS NOT NULL
  AND languages IS NOT NULL
  AND cardinality(languages) = 2
  AND any_match(languages, x -> x.lang = 'IT')
  AND concat(p_year, '-', p_month, '-', p_day) <= CAST(date_add('day', -1, current_date) AS varchar)
GROUP BY 1
ORDER BY numero_notifiche DESC;


-- Distribuzione tipologie AAR
-- Conteggio delle notifiche per tipologia AAR rilevata in timeline.

WITH notif AS (
  SELECT DISTINCT iun
  FROM "cdc_analytics_database"."pn_notifications_json_view"
  WHERE iun IS NOT NULL
    AND concat(p_year, '-', p_month, '-', p_day) <= CAST(current_date AS varchar)
),
timeline AS (
  SELECT DISTINCT iun, details_aarTemplateType
  FROM "cdc_analytics_database"."pn_timelines_json_view"
  WHERE iun IS NOT NULL
    AND details_aarTemplateType IS NOT NULL
    AND concat(p_year, '-', p_month, '-', p_day) <= CAST(current_date AS varchar)
)
SELECT
  t.details_aarTemplateType AS tipologia_aar,
  COUNT(*) AS numero_notifiche
FROM timeline t
INNER JOIN notif n
  ON t.iun = n.iun
GROUP BY t.details_aarTemplateType
ORDER BY numero_notifiche DESC, tipologia_aar;


-- Distribuzione bilingue per ente e lingua
-- Conteggio delle notifiche bilingue con IT per ente e seconda lingua.

SELECT
  senderpaid AS ente,
  senderDenomination AS denominazione_ente,
  element_at(
    filter(
      transform(languages, x -> x.lang),
      lang -> lang <> 'IT'
    ),
    1
  ) AS altra_lingua,
  COUNT(DISTINCT iun) AS numero_notifiche
FROM "cdc_analytics_database"."pn_notifications_json_view"
WHERE iun IS NOT NULL
  AND senderpaid IS NOT NULL
  AND languages IS NOT NULL
  AND cardinality(languages) = 2
  AND any_match(languages, x -> x.lang = 'IT')
  AND concat(p_year, '-', p_month, '-', p_day) <= CAST(date_add('day', -1, current_date) AS varchar)
GROUP BY 1, 2, 3
ORDER BY numero_notifiche DESC, ente, denominazione_ente, altra_lingua;