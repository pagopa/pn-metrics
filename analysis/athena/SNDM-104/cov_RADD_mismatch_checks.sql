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