-- 4. Коли Akira журнал купили?
SELECT m.title, s.sale_date, c.full_name AS buyer, st.name AS store
FROM magazine m
JOIN sale s     ON s.magazine_id = m.magazine_id
JOIN customer c ON c.customer_id = s.customer_id
JOIN store st   ON st.store_id   = s.store_id
WHERE m.title = 'Akira'
ORDER BY s.sale_date;
-- Очікувано: 3 продажі (2026-07-15, 2026-10-01, 2026-10-03)