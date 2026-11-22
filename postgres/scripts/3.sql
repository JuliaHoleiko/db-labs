SET search_path TO bookstore_app, public;

-- 1. Подання: повна деталізація покупок усіх клієнтів
CREATE OR REPLACE VIEW customer_purchases AS
SELECT
    c.customer_id,
    c.full_name       AS customer_name,
    c.email,
    s.sale_id,
    s.sale_date,
    m.magazine_id,
    m.title           AS magazine_title,
    m.series          AS magazine_series,
    st.name           AS store_name,
    d.name            AS department_name
FROM bookstore_app.customer c
LEFT JOIN bookstore_app.sale s       ON s.customer_id   = c.customer_id
LEFT JOIN bookstore_app.magazine m   ON m.magazine_id   = s.magazine_id
LEFT JOIN bookstore_app.department d ON d.department_id = s.department_id
LEFT JOIN bookstore_app.store st     ON st.store_id     = d.store_id;

-- 2. Функція: вводиш ID кастомера -> отримуєш таблицю його покупок
CREATE OR REPLACE FUNCTION get_customer_purchases(p_customer_id INT)
RETURNS TABLE (
    sale_id         INT,
    sale_date       DATE,
    magazine_title  VARCHAR,
    magazine_series VARCHAR,
    store_name      VARCHAR,
    department_name VARCHAR
) AS $$
    SELECT
        cp.sale_id,
        cp.sale_date,
        cp.magazine_title,
        cp.magazine_series,
        cp.store_name,
        cp.department_name
    FROM bookstore_app.customer_purchases cp
    WHERE cp.customer_id = p_customer_id
      AND cp.sale_id IS NOT NULL
    ORDER BY cp.sale_date DESC, cp.sale_id DESC;
$$ LANGUAGE sql STABLE;

-- 3. JSON-функція та синхронізація історії покупок у Memcached (/customer/{id}/purchases)
CREATE OR REPLACE FUNCTION customer_purchases_json(p_customer_id INT) RETURNS TEXT AS $$
    SELECT to_json(x)::TEXT
    FROM (
        SELECT
            c.customer_id,
            c.full_name AS customer_name,
            COALESCE(
                (
                    SELECT json_agg(p)
                    FROM bookstore_app.get_customer_purchases(c.customer_id) p
                ),
                '[]'::json
            ) AS purchases
        FROM bookstore_app.customer c
        WHERE c.customer_id = p_customer_id
    ) AS x;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE PROCEDURE sync_customer_purchases_to_cache()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT customer_id FROM bookstore_app.customer LOOP
        PERFORM public.memcache_set(
            '/customer/' || r.customer_id || '/purchases',
            bookstore_app.customer_purchases_json(r.customer_id)
        );
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION trg_sync_purchases_memcache() RETURNS trigger AS $$
DECLARE
    v_cust_id INT;
BEGIN
    v_cust_id := COALESCE(NEW.customer_id, OLD.customer_id);
    PERFORM public.memcache_set(
        '/customer/' || v_cust_id || '/purchases',
        bookstore_app.customer_purchases_json(v_cust_id)
    );
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sale_purchases_cache_sync ON bookstore_app.sale;
CREATE CONSTRAINT TRIGGER trg_sale_purchases_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON bookstore_app.sale
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_purchases_memcache();