-- Analisi dei documenti allegati alle notifiche per l'anno 2026, suddivisi per tipologia.
-- L'analisi include documenti di vario tipo (attachments, accepted attachments, f24 attachments, legal fact id) e i metadati degli allegati f24 presenti nelle notifiche.

WITH extracted_docs AS (

  -- generic documents type (attachments details)
  SELECT
    t.iun,
    t.details_recIndex AS rec_index,
    a.url AS document_key,
    regexp_extract(a.url, '(?:safestorage://)?([^-]+)-', 1) AS document_type
  FROM "cdc_analytics_database"."pn_timelines_json_view" t
  CROSS JOIN UNNEST(t.details_attachments) AS u(a)
  WHERE t.p_year = '2026'
    AND t.iun LIKE '%2026%'
    AND a.url IS NOT NULL

  UNION ALL

  -- (accepted attachments) documents type
  SELECT
    t.iun,
    t.details_recIndex AS rec_index,
    aa.filekey AS document_key,
    regexp_extract(aa.filekey, '(?:safestorage://)?([^-]+)-', 1) AS document_type
  FROM "cdc_analytics_database"."pn_timelines_json_view" t
  CROSS JOIN UNNEST(t.details_categorizedattachmentsresult_acceptedattachments) AS u(aa)
  WHERE t.p_year = '2026'
    AND t.iun LIKE '%2026%'
    AND aa.filekey IS NOT NULL

  UNION ALL

  -- (f24 attachments) documents type
  SELECT
    t.iun,
    t.details_recIndex AS rec_index,
    f24._elem_value AS document_key,
    regexp_extract(f24._elem_value, '(?:safestorage://)?([^-]+)-', 1) AS document_type
  FROM "cdc_analytics_database"."pn_timelines_json_view" t
  CROSS JOIN UNNEST(t.details_f24attachments) AS u(f24)
  WHERE t.p_year = '2026'
    AND t.iun LIKE '%2026%'
    AND f24._elem_value IS NOT NULL

  UNION ALL

  -- (legalfactid attachments) documents type
  SELECT
    t.iun,
    t.details_recIndex AS rec_index,
    lf.key AS document_key,
    regexp_extract(lf.key, '(?:safestorage://)?([^-]+)-', 1) AS document_type
  FROM "cdc_analytics_database"."pn_timelines_json_view" t
  CROSS JOIN UNNEST(t.legalfactid) AS u(lf)
  WHERE t.p_year = '2026'
    AND t.iun LIKE '%2026%'
    AND lf.key IS NOT NULL

  UNION ALL

  -- f24 metadata (notification)
  SELECT
    n.iun,
    NULL AS rec_index,
    p.f24_metadataAttachment_ref_key AS document_key,
    regexp_extract(p.f24_metadataAttachment_ref_key, '(?:safestorage://)?([^-]+)-', 1) AS document_type
  FROM "cdc_analytics_database"."pn_notifications_json_view" n
  CROSS JOIN UNNEST(n.recipients) AS u(r)
  CROSS JOIN UNNEST(r.payments) AS v(p)
  WHERE n.p_year = '2026'
    AND n.iun LIKE '%2026%'
    AND p.f24_metadataAttachment_ref_key IS NOT NULL

),

univoque_docs AS (
  SELECT DISTINCT
    iun,
    rec_index,
    document_key,
    document_type
  FROM extracted_docs
)

SELECT
  document_type,
  COUNT(*) AS num_docs,
  COUNT(DISTINCT iun) AS num_notifiche,
  COUNT(*) * 1.0 / COUNT(DISTINCT iun) AS avg_docs_per_notification
FROM univoque_docs
GROUP BY document_type
ORDER BY document_type;


-- Conteggio totale dei documenti per categoria REQUEST_ACCEPTED nel 2026 
SELECT COUNT(*) FROM "cdc_analytics_database"."pn_timelines_json_view"  WHERE p_year = '2026' AND category='REQUEST_ACCEPTED';