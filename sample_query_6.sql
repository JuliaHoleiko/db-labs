SELECT DISTINCT c.full_name, c.email
FROM sale s
JOIN customer c ON c.customer_id = s.customer_id
WHERE s.magazine_id IN (SELECT magazine_id
                        FROM stock
                        GROUP BY magazine_id
                        HAVING SUM(quantity) BETWEEN 1 AND 5);
-- Очікувано: 2 покупця які купляли журнал з ід 1 (Amazing Spider-Man), якого сумарно зі всіх магазинів 5 штук
