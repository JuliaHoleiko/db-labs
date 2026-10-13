-- 1. Які журнали було куплено певним покупцем? А саме покупцем з customer_id = 1
SELECT m.title, m.series, m.isbn, s.sale_date
FROM sale s
JOIN magazine   m  ON m.magazine_id   = s.magazine_id
WHERE s.customer_id = 1
ORDER BY s.sale_date;
-- Очікувано: Amazing Spider-Man (2026-08-10), Batman: Year One (2026-09-20), Akira (2026-10-01)