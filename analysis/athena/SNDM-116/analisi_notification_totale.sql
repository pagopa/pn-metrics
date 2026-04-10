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