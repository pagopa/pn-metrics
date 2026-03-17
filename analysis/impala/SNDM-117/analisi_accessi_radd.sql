WITH base AS (
    SELECT
        YEAR(ts) AS year,
        MONTH(ts) AS month,
        iun,
        MAX(CASE WHEN delegateId IS NOT NULL THEN 1 ELSE 0 END) AS has_delegate
    FROM (
        SELECT
            iun,
            delegateId,
            COALESCE(
                CAST(operationStartDate AS TIMESTAMP),
                FROM_UNIXTIME(CAST(ApproximateCreationDateTime / 1000 AS BIGINT))
            ) AS ts
        FROM send.silver_radd_transaction_entity
    ) t
    GROUP BY YEAR(ts), MONTH(ts), iun
)
SELECT
    year,
    month,
    SUM(has_delegate) AS with_delegate,
    COUNT(*) - SUM(has_delegate) AS without_delegate
FROM base
WHERE year BETWEEN 2024 AND 2026
GROUP BY year, month
ORDER BY year, month;