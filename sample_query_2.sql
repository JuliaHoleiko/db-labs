-- 2. Як називається журнал із заданим ISBN?
SELECT title
FROM magazine
WHERE isbn = '978-4-0631-0001-7';
-- Очікувано: Akira
 