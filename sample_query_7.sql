-- 7. Яка кількість покупців користується певним магазином?
SELECT st.name, COUNT(DISTINCT s.customer_id) AS customers_count
FROM store st
LEFT JOIN sale s ON s.store_id = st.store_id
WHERE st.name = 'Комікс-Центр'
GROUP BY st.name;
-- Очікувано: 2