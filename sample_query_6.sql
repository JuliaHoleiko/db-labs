-- 6. Знайти покупця рідкісних журналів (за наявності в магазині)
SELECT DISTINCT c.customer_id, c.full_name, c.email, m.title 
FROM sale s
JOIN customer c ON c.customer_id = s.customer_id
JOIN magazine m ON m.magazine_id = s.magazine_id
WHERE m.is_rare
  AND EXISTS (SELECT 1
              FROM stock st
              WHERE st.magazine_id = m.magazine_id
                AND st.quantity > 0)
ORDER BY c.customer_id;
-- Очікувано: 5 записів