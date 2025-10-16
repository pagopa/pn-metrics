select p_year,p_month,dynamodb.NewImage.version.s as version, count(*) as occurrences 
FROM cdc_analytics_database.pn_notifications AS t
where p_year in ('2024', '2025','2023')
and dynamodb.NewImage.version.s is not null
group by p_year,p_month ,dynamodb.NewImage.version.s
order by  p_year,p_month