-- 4. Коли журнал Akira (magazine_id = 3) купили?
SELECT m.title, s.sale_date, c.full_name AS buyer, st.name AS store
FROM magazine m
JOIN sale       s  ON s.magazine_id   = m.magazine_id
JOIN customer   c  ON c.customer_id   = s.customer_id
JOIN department d  ON d.department_id = s.department_id
JOIN store      st ON st.store_id     = d.store_id
WHERE m.magazine_id = 3
ORDER BY s.sale_date;
-- Очікувано: 3 продажі (2026-07-15, 2026-10-01, 2026-10-03)