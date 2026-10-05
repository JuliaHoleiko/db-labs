-- 1. Які журнали було куплено певним покупцем? А саме olena.kovalenko@example.com
SELECT m.title, m.series, m.isbn, s.sale_date, st.name AS store
FROM sale s
JOIN customer c ON c.customer_id = s.customer_id
JOIN magazine m ON m.magazine_id = s.magazine_id
JOIN store st   ON st.store_id   = s.store_id
WHERE c.email = 'olena.kovalenko@example.com'
ORDER BY s.sale_date;
-- Очікувано: Amazing Spider-Man (2026-08-10), Batman: Year One (2026-09-20), Akira (2026-10-01)
