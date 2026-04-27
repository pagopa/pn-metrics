-- Distribuzione totale per lingua
-- Conteggio complessivo delle notifiche per lingua valorizzata.

SELECT
  lang.lang AS lingua,
  COUNT(DISTINCT iun) AS numero_notifiche
FROM "cdc_analytics_database"."pn_notifications_json_view"
CROSS JOIN UNNEST(languages) AS lang (lang)
WHERE iun IS NOT NULL
  AND languages IS NOT NULL
  AND lang.lang IS NOT NULL
  AND concat(p_year, '-', p_month, '-', p_day) <= CAST(date_add('day', -1, current_date) AS varchar)
GROUP BY 1
ORDER BY numero_notifiche DESC;


-- Query di verifica per notifiche bilingue con IT e AAR non rilevato in timeline

WITH notif_multilingua AS (
  SELECT DISTINCT iun
  FROM "cdc_analytics_database"."pn_notifications_json_view"
  WHERE iun IS NOT NULL
    AND languages IS NOT NULL
    AND cardinality(languages) = 2
    AND any_match(languages, x -> x.lang = 'IT')
    AND concat(p_year, '-', p_month, '-', p_day) <= CAST(current_date AS varchar)
),
timeline_aar AS (
  SELECT DISTINCT iun
  FROM "cdc_analytics_database"."pn_timelines_json_view"
  WHERE iun IS NOT NULL
    AND details_aarTemplateType IS NOT NULL
    AND concat(p_year, '-', p_month, '-', p_day) <= CAST(current_date AS varchar)
)
SELECT n.iun
FROM notif_multilingua n
LEFT JOIN timeline_aar t
  ON n.iun = t.iun
WHERE t.iun IS NULL
LIMIT 10;

-- Query di verifica per notifiche bilingue con IT e AAR non rilevato in timeline (dettaglio) 

SELECT *
FROM "cdc_analytics_database"."pn_notifications_json_view"
WHERE iun = 'YEGZ-XNPZ-UETG-202506-W-1'
  AND CAST(
        CONCAT(
          CAST(p_year AS varchar), '-',
          LPAD(CAST(p_month AS varchar), 2, '0'), '-',
          LPAD(CAST(p_day AS varchar), 2, '0')
        ) AS date
      ) = DATE '2025-06-25';