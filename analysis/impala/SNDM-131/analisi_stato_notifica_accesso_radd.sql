-- NOTE: Table references have been anonymized. Replace placeholders before execution.
WITH timeline_filtered AS (
    SELECT
        iun,
        `timestamp` AS ts,
        category,
        statusinfo.actual AS status
    FROM <schema>.<s_tl_events>
    WHERE
        category = 'NOTIFICATION_RADD_RETRIEVED'
        OR statusinfo.actual IS NOT NULL
),

radd_events AS (
    SELECT
        iun,
        ts AS radd_ts
    FROM timeline_filtered
    WHERE category = 'NOTIFICATION_RADD_RETRIEVED'
),

status_events AS (
    SELECT
        iun,
        ts AS status_ts,
        status
    FROM timeline_filtered
    WHERE status IS NOT NULL
),

joined AS (
    SELECT
        r.iun,
        r.radd_ts,
        s.status,
        ROW_NUMBER() OVER (
            PARTITION BY r.iun, r.radd_ts
            ORDER BY s.status_ts DESC
        ) AS rn
    FROM radd_events r
    JOIN status_events s
        ON r.iun = s.iun
        AND s.status_ts <= r.radd_ts
)

SELECT
    status,
    COUNT(DISTINCT iun) AS frequency
FROM joined
WHERE rn = 1
GROUP BY status
ORDER BY frequency DESC;