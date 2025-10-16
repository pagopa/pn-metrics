select p_year,p_month,version , count(*) as occurrences
from (  select  p_year,
                p_month,
                dynamodb.NewImage.version.s as version,
               dynamodb.NewImage.senderpaid.s
        FROM cdc_analytics_database.pn_notifications AS t
        where p_year in ('2024','2025','2023')
        and dynamodb.NewImage.version.s is not null
        group by p_year,p_month ,dynamodb.NewImage.version.s, dynamodb.NewImage.senderpaid.s)
group by p_year,p_month ,version
order by  p_year,p_month 