-- 3. Який ISBN у журналу із заданою назвою?
SELECT title, isbn
FROM magazine
WHERE title = 'Akira';
-- Очікувано: 978-4-0631-0001-7