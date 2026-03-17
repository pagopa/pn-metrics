-- 1) Notifiche (distinct IUN) con status COMPLETED,
--    suddivise tra "con delegato" e "senza delegato",
--    calcolate mensilmente a partire da 2024-11 sulla base di ApproximateCreationDateTime

WITH base_iun AS (
    SELECT
        YEAR(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))) AS year,
        MONTH(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))) AS month,
        iun,
        MAX(CASE WHEN delegateId IS NOT NULL THEN 1 ELSE 0 END) AS has_delegate
    FROM send.silver_radd_transaction_entity
    WHERE operation_status = 'COMPLETED'
      AND FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT)) >= '2024-11-01'
    GROUP BY YEAR(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))),
             MONTH(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))),
             iun
)
SELECT
    year,
    month,
    SUM(has_delegate) AS with_delegate_iun,
    COUNT(*) - SUM(has_delegate) AS without_delegate_iun
FROM base_iun
GROUP BY year, month
ORDER BY year, month;


-- 2) Accessi RADD (distinct transactionId) con status COMPLETED,
--    suddivisi tra "con delegato" e "senza delegato",
--    calcolati mensilmente a partire da 2024-11 sulla base di ApproximateCreationDateTime

WITH base_tx AS (
    SELECT
        YEAR(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))) AS year,
        MONTH(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))) AS month,
        transactionId,
        MAX(CASE WHEN delegateId IS NOT NULL THEN 1 ELSE 0 END) AS has_delegate
    FROM send.silver_radd_transaction_entity
    WHERE operation_status = 'COMPLETED'
      AND FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT)) >= '2024-11-01'
    GROUP BY YEAR(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))),
             MONTH(FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))),
             transactionId
)
SELECT
    year,
    month,
    SUM(has_delegate) AS with_delegate_tx,
    COUNT(*) - SUM(has_delegate) AS without_delegate_tx
FROM base_tx
GROUP BY year, month
ORDER BY year, month;