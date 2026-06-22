SELECT
  COUNT(CASE WHEN description IS NULL THEN 1 END) AS cnt_null_description,
  COUNT(CASE WHEN description IS NOT NULL AND TRIM(description) = '' THEN 1 END) AS cnt_empty_description
FROM "cdc_analytics_database"."pn_radd_registry_v2_json_view"
WHERE CAST(
        CONCAT(
          CAST(p_year AS varchar), '-',
          LPAD(CAST(p_month AS varchar), 2, '0'), '-',
          LPAD(CAST(p_day AS varchar), 2, '0')
        ) AS date
      ) <= date_add('day', -1, current_date);
      
--null: 9774
--empty: 64     
      
 -------------------phoneNumbers-------------------------
      
      SELECT
  COUNT(CASE WHEN phoneNumbers IS NULL THEN 1 END) AS cnt_null_phoneNumbers,
  COUNT(CASE WHEN phoneNumbers IS NOT NULL AND CARDINALITY(phoneNumbers) = 0 THEN 1 END) AS cnt_empty_phoneNumbers
FROM "cdc_analytics_database"."pn_radd_registry_v2_json_view"
WHERE CAST(
        CONCAT(
          CAST(p_year AS varchar), '-',
          LPAD(CAST(p_month AS varchar), 2, '0'), '-',
          LPAD(CAST(p_day AS varchar), 2, '0')
        ) AS date
      ) <= date_add('day', -1, current_date);

--null: 9774
--empty: 0
      
 -------------------startValidity-------------------------
      
      SELECT
  COUNT(CASE WHEN startValidity IS NULL THEN 1 END) AS cnt_null_startValidity,
  COUNT(CASE WHEN startValidity IS NOT NULL AND TRIM(startValidity) = '' THEN 1 END) AS cnt_empty_startValidity
FROM "cdc_analytics_database"."pn_radd_registry_v2_json_view"
WHERE CAST(
        CONCAT(
          CAST(p_year AS varchar), '-',
          LPAD(CAST(p_month AS varchar), 2, '0'), '-',
          LPAD(CAST(p_day AS varchar), 2, '0')
        ) AS date
      ) <= date_add('day', -1, current_date);

--null: 9804
--empty: 0      
      
 -------------------externalCodes-------------------------    
      
      SELECT
  COUNT(CASE WHEN externalCodes IS NULL THEN 1 END) AS cnt_null_externalCodes,
  COUNT(CASE WHEN externalCodes IS NOT NULL AND CARDINALITY(externalCodes) = 0 THEN 1 END) AS cnt_empty_externalCodes
FROM "cdc_analytics_database"."pn_radd_registry_v2_json_view"
WHERE CAST(
        CONCAT(
          CAST(p_year AS varchar), '-',
          LPAD(CAST(p_month AS varchar), 2, '0'), '-',
          LPAD(CAST(p_day AS varchar), 2, '0')
        ) AS date
      ) <= date_add('day', -1, current_date);
      
--null: 9774
--empty: 0      
      
 -------------------partnerType-------------------------   
    
    
    SELECT
  COUNT(CASE WHEN partnerType IS NULL THEN 1 END) AS cnt_null_partnerType,
  COUNT(CASE WHEN partnerType IS NOT NULL AND TRIM(partnerType) = '' THEN 1 END) AS cnt_empty_partnerType
FROM "cdc_analytics_database"."pn_radd_registry_v2_json_view"
WHERE CAST(
        CONCAT(
          CAST(p_year AS varchar), '-',
          LPAD(CAST(p_month AS varchar), 2, '0'), '-',
          LPAD(CAST(p_day AS varchar), 2, '0')
        ) AS date
      ) <= date_add('day', -1, current_date);
      
--null: 9774
--empty: 0  