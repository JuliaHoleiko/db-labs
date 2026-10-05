-- 8. Скільки покупців молодших за 20 років?
SELECT COUNT(*) AS under_20
FROM customer
WHERE birth_date > CURRENT_DATE - INTERVAL '20 years';
-- Очікувано: 2 (Бондар, Ткаченко)