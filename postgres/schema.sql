CREATE ROLE bookstore_app LOGIN;

DROP DATABASE IF EXISTS bookstore;

-- For Linux (Docker container)
CREATE DATABASE bookstore ENCODING 'UTF-8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0 OWNER bookstore_app;

\c bookstore

CREATE EXTENSION IF NOT EXISTS pgmemcache;

CREATE SCHEMA bookstore_app AUTHORIZATION bookstore_app;

-- Додаємо public у search_path, щоб були доступні функції pgmemcache
SET search_path TO bookstore_app, public;
SET ROLE bookstore_app;

-- =====================================================================
-- 1. ТАБЛИЦІ БАЗИ ДАНИХ
-- =====================================================================

-- 1. Автори
CREATE TABLE author (
    author_id  SERIAL PRIMARY KEY,
    full_name  VARCHAR(200) NOT NULL
);

-- 2. Журнали
CREATE TABLE magazine (
    magazine_id   SERIAL PRIMARY KEY,
    title         VARCHAR(255) NOT NULL,
    series        VARCHAR(200),
    publisher     VARCHAR(200) NOT NULL,
    year          SMALLINT NOT NULL CHECK (year BETWEEN 1800 AND 2100),
    isbn          VARCHAR(17) NOT NULL UNIQUE
);

-- 3. Журнал <-> Автор (M:N)
CREATE TABLE magazine_author (
    magazine_id  INT NOT NULL REFERENCES magazine(magazine_id) ON DELETE CASCADE,
    author_id    INT NOT NULL REFERENCES author(author_id),
    PRIMARY KEY (magazine_id, author_id)
);

-- 4. Магазини
CREATE TABLE store (
    store_id  SERIAL PRIMARY KEY,
    name      VARCHAR(200) NOT NULL UNIQUE,
    address   VARCHAR(300)
);

-- 5. Відділи магазину
CREATE TABLE department (
    department_id  SERIAL PRIMARY KEY,
    store_id       INT NOT NULL REFERENCES store(store_id) ON DELETE CASCADE,
    dept_number    SMALLINT NOT NULL,
    name           VARCHAR(200) NOT NULL,
    capacity       INT NOT NULL CHECK (capacity >= 0),
    UNIQUE (store_id, dept_number)
);

-- 6. Наявність журналів у відділах
CREATE TABLE stock (
    department_id  INT NOT NULL REFERENCES department(department_id) ON DELETE CASCADE,
    magazine_id    INT NOT NULL REFERENCES magazine(magazine_id),
    quantity       INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    PRIMARY KEY (department_id, magazine_id)
);

-- 7. Покупці
CREATE TABLE customer (
    customer_id   SERIAL PRIMARY KEY,
    email         VARCHAR(254) NOT NULL UNIQUE,
    full_name     VARCHAR(250) NOT NULL,
    birth_date    DATE NOT NULL,
    address       VARCHAR(300),
    phone         VARCHAR(20),
    best_store_id INT REFERENCES store(store_id) ON DELETE SET NULL
);

-- 8. Продажі
CREATE TABLE sale (
    sale_id        SERIAL PRIMARY KEY,
    customer_id    INT  NOT NULL REFERENCES customer(customer_id),
    department_id  INT  NOT NULL,
    magazine_id    INT  NOT NULL,
    sale_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT fk_sale_stock
        FOREIGN KEY (department_id, magazine_id)
        REFERENCES stock (department_id, magazine_id)
);

-- =====================================================================
-- 2. БІЗНЕС-ТРИГЕРИ ЦІЛІСНОСТІ ТА ОБЛІКУ
-- =====================================================================

CREATE FUNCTION recalc_best_store(p_customer INT) RETURNS void AS $$
BEGIN
    UPDATE bookstore_app.customer
    SET best_store_id = (
        SELECT d.store_id
        FROM bookstore_app.sale s
        JOIN bookstore_app.department d ON d.department_id = s.department_id
        WHERE s.customer_id = p_customer
        GROUP BY d.store_id
        ORDER BY COUNT(*) DESC, MAX(s.sale_date) DESC, MAX(s.sale_id) DESC 
        LIMIT 1
    )
    WHERE customer_id = p_customer;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION trg_best_store() RETURNS trigger AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM bookstore_app.recalc_best_store(NEW.customer_id);
    END IF;
    IF TG_OP = 'DELETE'
       OR (TG_OP = 'UPDATE' AND OLD.customer_id IS DISTINCT FROM NEW.customer_id) THEN
        PERFORM bookstore_app.recalc_best_store(OLD.customer_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_best_store
AFTER INSERT OR DELETE OR UPDATE OF customer_id, department_id, sale_date ON sale
FOR EACH ROW EXECUTE FUNCTION trg_best_store();

CREATE FUNCTION check_department_capacity() RETURNS trigger AS $$
DECLARE
    v_capacity INT;
    v_total    INT;
BEGIN
    SELECT capacity INTO v_capacity
    FROM bookstore_app.department
    WHERE department_id = NEW.department_id
    FOR UPDATE;

    SELECT COALESCE(SUM(quantity), 0) INTO v_total
    FROM bookstore_app.stock
    WHERE department_id = NEW.department_id
      AND magazine_id <> NEW.magazine_id;

    IF v_total + NEW.quantity > v_capacity THEN
        RAISE EXCEPTION
            'Відділ % переповнений: місткість %, буде %',
            NEW.department_id, v_capacity, v_total + NEW.quantity;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_capacity
BEFORE INSERT OR UPDATE OF quantity, department_id ON stock
FOR EACH ROW EXECUTE FUNCTION check_department_capacity();

CREATE FUNCTION check_capacity_not_below_stock() RETURNS trigger AS $$
BEGIN
    IF (SELECT COALESCE(SUM(quantity),0) FROM bookstore_app.stock
        WHERE department_id = NEW.department_id) > NEW.capacity THEN
        RAISE EXCEPTION 'Нова місткість менша за поточну кількість журналів';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_department_capacity
BEFORE UPDATE OF capacity ON department
FOR EACH ROW EXECUTE FUNCTION check_capacity_not_below_stock();

CREATE FUNCTION sale_decrease_stock() RETURNS trigger AS $$
BEGIN
    UPDATE bookstore_app.stock
    SET quantity = quantity - 1
    WHERE department_id = NEW.department_id
      AND magazine_id   = NEW.magazine_id
      AND quantity > 0;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Журнал % відсутній у відділі %',
                         NEW.magazine_id, NEW.department_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_stock
BEFORE INSERT ON sale
FOR EACH ROW EXECUTE FUNCTION sale_decrease_stock();

CREATE FUNCTION sale_restore_stock() RETURNS trigger AS $$
BEGIN
    UPDATE bookstore_app.stock SET quantity = quantity + 1
    WHERE department_id = OLD.department_id AND magazine_id = OLD.magazine_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_restore
AFTER DELETE ON sale
FOR EACH ROW EXECUTE FUNCTION sale_restore_stock();

CREATE FUNCTION sale_update_stock() RETURNS trigger AS $$
BEGIN
    UPDATE bookstore_app.stock
    SET quantity = quantity + 1
    WHERE department_id = OLD.department_id
      AND magazine_id   = OLD.magazine_id;

    UPDATE bookstore_app.stock
    SET quantity = quantity - 1
    WHERE department_id = NEW.department_id
      AND magazine_id   = NEW.magazine_id
      AND quantity > 0;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Журнал % відсутній у відділі %',
                         NEW.magazine_id, NEW.department_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_update_stock
BEFORE UPDATE OF department_id, magazine_id ON sale
FOR EACH ROW
WHEN (OLD.department_id IS DISTINCT FROM NEW.department_id
      OR OLD.magazine_id IS DISTINCT FROM NEW.magazine_id)
EXECUTE FUNCTION sale_update_stock();

-CREATE ROLE bookstore_app LOGIN;

DROP DATABASE IF EXISTS bookstore;

-- For Linux (Docker container)
CREATE DATABASE bookstore ENCODING 'UTF-8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0 OWNER bookstore_app;

\c bookstore

CREATE EXTENSION IF NOT EXISTS pgmemcache;

CREATE SCHEMA bookstore_app AUTHORIZATION bookstore_app;

-- Додаємо public у search_path, щоб були доступні функції pgmemcache
SET search_path TO bookstore_app, public;
SET ROLE bookstore_app;

-- =====================================================================
-- 1. ТАБЛИЦІ БАЗИ ДАНИХ
-- =====================================================================

-- 1. Автори
CREATE TABLE author (
    author_id  SERIAL PRIMARY KEY,
    full_name  VARCHAR(200) NOT NULL
);

-- 2. Журнали
CREATE TABLE magazine (
    magazine_id   SERIAL PRIMARY KEY,
    title         VARCHAR(255) NOT NULL,
    series        VARCHAR(200),
    publisher     VARCHAR(200) NOT NULL,
    year          SMALLINT NOT NULL CHECK (year BETWEEN 1800 AND 2100),
    isbn          VARCHAR(17) NOT NULL UNIQUE
);

-- 3. Журнал <-> Автор (M:N)
CREATE TABLE magazine_author (
    magazine_id  INT NOT NULL REFERENCES magazine(magazine_id) ON DELETE CASCADE,
    author_id    INT NOT NULL REFERENCES author(author_id),
    PRIMARY KEY (magazine_id, author_id)
);

-- 4. Магазини
CREATE TABLE store (
    store_id  SERIAL PRIMARY KEY,
    name      VARCHAR(200) NOT NULL UNIQUE,
    address   VARCHAR(300)
);

-- 5. Відділи магазину
CREATE TABLE department (
    department_id  SERIAL PRIMARY KEY,
    store_id       INT NOT NULL REFERENCES store(store_id) ON DELETE CASCADE,
    dept_number    SMALLINT NOT NULL,
    name           VARCHAR(200) NOT NULL,
    capacity       INT NOT NULL CHECK (capacity >= 0),
    UNIQUE (store_id, dept_number)
);

-- 6. Наявність журналів у відділах
CREATE TABLE stock (
    department_id  INT NOT NULL REFERENCES department(department_id) ON DELETE CASCADE,
    magazine_id    INT NOT NULL REFERENCES magazine(magazine_id),
    quantity       INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    PRIMARY KEY (department_id, magazine_id)
);

-- 7. Покупці
CREATE TABLE customer (
    customer_id   SERIAL PRIMARY KEY,
    email         VARCHAR(254) NOT NULL UNIQUE,
    full_name     VARCHAR(250) NOT NULL,
    birth_date    DATE NOT NULL,
    address       VARCHAR(300),
    phone         VARCHAR(20),
    best_store_id INT REFERENCES store(store_id) ON DELETE SET NULL
);

-- 8. Продажі
CREATE TABLE sale (
    sale_id        SERIAL PRIMARY KEY,
    customer_id    INT  NOT NULL REFERENCES customer(customer_id),
    department_id  INT  NOT NULL,
    magazine_id    INT  NOT NULL,
    sale_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT fk_sale_stock
        FOREIGN KEY (department_id, magazine_id)
        REFERENCES stock (department_id, magazine_id)
);

-- =====================================================================
-- 2. БІЗНЕС-ТРИГЕРИ ЦІЛІСНОСТІ ТА ОБЛІКУ
-- =====================================================================

CREATE FUNCTION recalc_best_store(p_customer INT) RETURNS void AS $$
BEGIN
    UPDATE bookstore_app.customer
    SET best_store_id = (
        SELECT d.store_id
        FROM bookstore_app.sale s
        JOIN bookstore_app.department d ON d.department_id = s.department_id
        WHERE s.customer_id = p_customer
        GROUP BY d.store_id
        ORDER BY COUNT(*) DESC, MAX(s.sale_date) DESC, MAX(s.sale_id) DESC 
        LIMIT 1
    )
    WHERE customer_id = p_customer;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION trg_best_store() RETURNS trigger AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM bookstore_app.recalc_best_store(NEW.customer_id);
    END IF;
    IF TG_OP = 'DELETE'
       OR (TG_OP = 'UPDATE' AND OLD.customer_id IS DISTINCT FROM NEW.customer_id) THEN
        PERFORM bookstore_app.recalc_best_store(OLD.customer_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_best_store
AFTER INSERT OR DELETE OR UPDATE OF customer_id, department_id, sale_date ON sale
FOR EACH ROW EXECUTE FUNCTION trg_best_store();

CREATE FUNCTION check_department_capacity() RETURNS trigger AS $$
DECLARE
    v_capacity INT;
    v_total    INT;
BEGIN
    SELECT capacity INTO v_capacity
    FROM bookstore_app.department
    WHERE department_id = NEW.department_id
    FOR UPDATE;

    SELECT COALESCE(SUM(quantity), 0) INTO v_total
    FROM bookstore_app.stock
    WHERE department_id = NEW.department_id
      AND magazine_id <> NEW.magazine_id;

    IF v_total + NEW.quantity > v_capacity THEN
        RAISE EXCEPTION
            'Відділ % переповнений: місткість %, буде %',
            NEW.department_id, v_capacity, v_total + NEW.quantity;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_capacity
BEFORE INSERT OR UPDATE OF quantity, department_id ON stock
FOR EACH ROW EXECUTE FUNCTION check_department_capacity();

CREATE FUNCTION check_capacity_not_below_stock() RETURNS trigger AS $$
BEGIN
    IF (SELECT COALESCE(SUM(quantity),0) FROM bookstore_app.stock
        WHERE department_id = NEW.department_id) > NEW.capacity THEN
        RAISE EXCEPTION 'Нова місткість менша за поточну кількість журналів';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_department_capacity
BEFORE UPDATE OF capacity ON department
FOR EACH ROW EXECUTE FUNCTION check_capacity_not_below_stock();

CREATE FUNCTION sale_decrease_stock() RETURNS trigger AS $$
BEGIN
    UPDATE bookstore_app.stock
    SET quantity = quantity - 1
    WHERE department_id = NEW.department_id
      AND magazine_id   = NEW.magazine_id
      AND quantity > 0;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Журнал % відсутній у відділі %',
                         NEW.magazine_id, NEW.department_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_stock
BEFORE INSERT ON sale
FOR EACH ROW EXECUTE FUNCTION sale_decrease_stock();

CREATE FUNCTION sale_restore_stock() RETURNS trigger AS $$
BEGIN
    UPDATE bookstore_app.stock SET quantity = quantity + 1
    WHERE department_id = OLD.department_id AND magazine_id = OLD.magazine_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_restore
AFTER DELETE ON sale
FOR EACH ROW EXECUTE FUNCTION sale_restore_stock();

CREATE FUNCTION sale_update_stock() RETURNS trigger AS $$
BEGIN
    UPDATE bookstore_app.stock
    SET quantity = quantity + 1
    WHERE department_id = OLD.department_id
      AND magazine_id   = OLD.magazine_id;

    UPDATE bookstore_app.stock
    SET quantity = quantity - 1
    WHERE department_id = NEW.department_id
      AND magazine_id   = NEW.magazine_id
      AND quantity > 0;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Журнал % відсутній у відділі %',
                         NEW.magazine_id, NEW.department_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_update_stock
BEFORE UPDATE OF department_id, magazine_id ON sale
FOR EACH ROW
WHEN (OLD.department_id IS DISTINCT FROM NEW.department_id
      OR OLD.magazine_id IS DISTINCT FROM NEW.magazine_id)
EXECUTE FUNCTION sale_update_stock();

-- =====================================================================
-- 3. АНАЛІТИЧНІ ПОДАННЯ ТА ФУНКЦІЇ ВИБІРКИ
-- =====================================================================

-- 3.1. Зведена інформація по кожному магазину та його відділах
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

-- 3.2. Історія покупок клієнтів
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

CREATE OR REPLACE FUNCTION customer_purchases_json(p_customer_id INT) RETURNS TEXT AS $$
    SELECT jsonb_build_object(
        'customer_id', c.customer_id,
        'customer_name', c.full_name,
        'purchases', COALESCE(
            (
                SELECT jsonb_agg(to_jsonb(p))
                FROM bookstore_app.get_customer_purchases(c.customer_id) p
            ),
            '[]'::jsonb
        )
    )::TEXT
    FROM bookstore_app.customer c
    WHERE c.customer_id = p_customer_id;
$$ LANGUAGE sql STABLE;

-- =====================================================================
-- 4. БІЗНЕС-ПРОЦЕДУРИ ТА ПРОЦЕДУРИ СИНХРОНІЗАЦІЇ З MEMCACHED
-- =====================================================================

-- Бізнес-процедура оформлення продажу на касі
CREATE OR REPLACE PROCEDURE register_sale(
    p_customer_id   INT,
    p_department_id INT,
    p_magazine_id   INT,
    p_sale_date     DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM bookstore_app.customer WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Покупця з ID % не знайдено', p_customer_id;
    END IF;

    INSERT INTO bookstore_app.sale (customer_id, department_id, magazine_id, sale_date)
    VALUES (p_customer_id, p_department_id, p_magazine_id, p_sale_date);
END;
$$;

-- Прогрів кешу: журнали (/magazine/{id})
CREATE OR REPLACE PROCEDURE sync_magazines_to_cache()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT magazine_id, title, series, publisher, year, isbn
        FROM bookstore_app.magazine
    LOOP
        PERFORM public.memcache_set(
            '/magazine/' || rec.magazine_id,
            row_to_json(rec)::text
        );
    END LOOP;
END;
$$;

-- Прогрів кешу: покупці (/customer/{id})
CREATE OR REPLACE PROCEDURE sync_customers_to_cache()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT customer_id, full_name, email, phone, best_store_id
        FROM bookstore_app.customer
    LOOP
        PERFORM public.memcache_set(
            '/customer/' || rec.customer_id,
            row_to_json(rec)::text
        );
    END LOOP;
END;
$$;

-- Прогрів кешу: магазини та відділи (/store/{id})
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

-- Прогрів кешу: історія покупок клієнтів (/customer/{id}/purchases)
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

-- Загальна процедура повного прогріву кешу
CREATE OR REPLACE PROCEDURE sync_all_to_cache()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL bookstore_app.sync_magazines_to_cache();
    CALL bookstore_app.sync_customers_to_cache();
    CALL bookstore_app.sync_stores_to_cache();
    CALL bookstore_app.sync_customer_purchases_to_cache();
END;
$$;

-- =====================================================================
-- 5. ВІДКЛАДЕНІ ТРИГЕРИ (DEFERRABLE) ДЛЯ СИНХРОНІЗАЦІЇ З MEMCACHED
-- =====================================================================

-- 5.1. Синхронізація журналів
CREATE OR REPLACE FUNCTION trg_sync_magazine_memcache() RETURNS trigger AS $$
DECLARE
    v_json TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM public.memcache_delete('/magazine/' || OLD.magazine_id);
        RETURN OLD;
    ELSE
        SELECT row_to_json(t)::text INTO v_json
        FROM (
            SELECT NEW.magazine_id, NEW.title, NEW.series, NEW.publisher, NEW.year, NEW.isbn
        ) t;
        PERFORM public.memcache_set('/magazine/' || NEW.magazine_id, v_json);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_magazine_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON magazine
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_magazine_memcache();

-- 5.2. Синхронізація покупців
CREATE OR REPLACE FUNCTION trg_sync_customer_memcache() RETURNS trigger AS $$
DECLARE
    v_json TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM public.memcache_delete('/customer/' || OLD.customer_id);
        RETURN OLD;
    ELSE
        SELECT row_to_json(t)::text INTO v_json
        FROM (
            SELECT NEW.customer_id, NEW.full_name, NEW.email, NEW.phone, NEW.best_store_id
        ) t;
        PERFORM public.memcache_set('/customer/' || NEW.customer_id, v_json);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_customer_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON customer
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_customer_memcache();

-- 5.3. Синхронізація магазинів та відділів
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

CREATE CONSTRAINT TRIGGER trg_store_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON store
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_store_memcache();

CREATE CONSTRAINT TRIGGER trg_department_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON department
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_store_memcache();

-- 5.4. Синхронізація історії покупок клієнтів при продажах
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

CREATE CONSTRAINT TRIGGER trg_sale_purchases_cache_sync
AFTER INSERT OR UPDATE OR DELETE ON sale
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_sync_purchases_memcache();

