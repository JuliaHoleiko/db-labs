SET search_path TO bookstore_app, public;

-- 1. Подання: зведена інформація по кожному магазину та його відділах
CREATE OR REPLACE VIEW store_overview AS
SELECT
    s.store_id,
    s.name AS store_name,
    s.address,
    COUNT(DISTINCT d.department_id)::INTEGER AS departments_count,
    COALESCE((SELECT SUM(d2.capacity) FROM bookstore_app.department d2 WHERE d2.store_id = s.store_id), 0)::INTEGER AS total_capacity,
    COALESCE(SUM(st.quantity), 0)::INTEGER AS total_occupied,
    COALESCE(
        STRING_AGG(
            DISTINCT d.name || ' (місткість: ' || d.capacity || ')',
            ', '
        ),
        'Відділів немає'
    ) AS departments_list
FROM bookstore_app.store s
LEFT JOIN bookstore_app.department d ON d.store_id = s.store_id
LEFT JOIN bookstore_app.stock st ON st.department_id = d.department_id
GROUP BY s.store_id, s.name, s.address;

-- 2. Функція формування JSON для одного магазину на основі подання
CREATE OR REPLACE FUNCTION store_json(p_store_id INTEGER) RETURNS TEXT AS $$
    SELECT to_json(x)::TEXT
    FROM (
        SELECT
            store_id,
            store_name,
            address,
            departments_count,
            total_capacity,
            total_occupied,
            departments_list
        FROM bookstore_app.store_overview
        WHERE store_id = p_store_id
    ) AS x;
$$ LANGUAGE sql STABLE;

-- 3. Процедура прогріву кешу для магазинів (/store/{id})
CREATE OR REPLACE PROCEDURE sync_stores_to_cache()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT store_id FROM bookstore_app.store LOOP
        PERFORM public.memcache_set(
            '/store/' || r.store_id,
            bookstore_app.store_json(r.store_id)
        );
    END LOOP;
END;
$$;

-- Загальна процедура прогріву кешу
CREATE OR REPLACE PROCEDURE sync_all_to_cache()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL bookstore_app.sync_magazines_to_cache();
    CALL bookstore_app.sync_customers_to_cache();
    CALL bookstore_app.sync_stores_to_cache();
END;
$$;

-- 4. Відкладений тригер для автоматичного оновлення кешу при зміні відділів чи магазинів
CREATE OR REPLACE FUNCTION trg_sync_store_memcache() RETURNS trigger AS $$
DECLARE
    v_store_id INT;
BEGIN
    v_store_id := COALESCE(NEW.store_id, OLD.store_id);
    IF EXISTS (SELECT 1 FROM bookstore_app.store WHERE store_id = v_store_id) THEN
        PERFORM public.memcache_set(
            '/store/' || v_store_id,
            bookstore_app.store_json(v_store_id)
        );
    ELSE
        PERFORM public.memcache_delete('/store/' || v_store_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_store_cache_sync ON bookstore_app.store;
CREATE CONSTRAINT TRIGGER trg_store_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON bookstore_app.store
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_store_memcache();

DROP TRIGGER IF EXISTS trg_department_cache_sync ON bookstore_app.department;
CREATE CONSTRAINT TRIGGER trg_department_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON bookstore_app.department
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_store_memcache();