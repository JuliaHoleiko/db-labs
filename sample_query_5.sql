-- 5. Хто з покупців купив журнал понад місяць тому?

SELECT DISTINCT c.customer_id, c.full_name, c.email
FROM sale s
JOIN customer c ON c.customer_id = s.customer_id
WHERE s.sale_date < CURRENT_DATE - INTERVAL '1 month'
ORDER BY c.customer_id;
-- Очікувано (станом на жовтень 2026): Коваленко, Шевченко, Мельник