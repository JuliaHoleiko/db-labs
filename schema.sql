DROP DATABASE IF EXISTS lab2;

CREATE ROLE testuser LOGIN;

--For linux
CREATE DATABASE lab2 ENCODING 'UTF-8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0 OWNER testuser;

\c lab2

SET ROLE testuser;
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
 
-- 3. Журнал <-> Автор проміжна таблиця (багато до багатьох)
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
 
-- 6. Наявність журналів у відділах (надходження = збільшити quantity, списання = зменшити)
CREATE TABLE stock (
    department_id  INT NOT NULL REFERENCES department(department_id) ON DELETE CASCADE,
    magazine_id    INT NOT NULL REFERENCES magazine(magazine_id),
    quantity       INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    PRIMARY KEY (department_id, magazine_id)
);
 
-- 7. Покупці
CREATE TABLE customer (
    customer_id  SERIAL PRIMARY KEY,
    email        VARCHAR(254) NOT NULL UNIQUE,
    full_name    VARCHAR(250) NOT NULL,
    birth_date   DATE NOT NULL,
    address      VARCHAR(300),
    phone        VARCHAR(20),
    best_store_id INT REFERENCES store(store_id) ON DELETE SET NULL
                                  -- улюблений магазин (де найчастіше купує),
                                  -- оновлюється тригером після кожного продажу
);
 
-- 8. Продажі: хто, де (в якому магазині), що і коли купив
CREATE TABLE sale (
    sale_id      SERIAL PRIMARY KEY,
    customer_id  INT  NOT NULL REFERENCES customer(customer_id),
    store_id     INT  NOT NULL REFERENCES store(store_id),
    magazine_id  INT  NOT NULL REFERENCES magazine(magazine_id),
    -- department_id  INT  NOT NULL REFERENCES department(department_id),
    sale_date    DATE NOT NULL DEFAULT CURRENT_DATE
);
 
-- ТРИГЕР: після кожного продажу перераховує кращий магазин покупця
CREATE FUNCTION update_best_store() RETURNS trigger AS $$
BEGIN
    UPDATE customer
    SET best_store_id = (
        SELECT store_id
        FROM sale
        WHERE customer_id = NEW.customer_id
        GROUP BY store_id
        ORDER BY COUNT(*) DESC, store_id
        LIMIT 1
    )
    WHERE customer_id = NEW.customer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
 
CREATE TRIGGER trg_sale_best_store
AFTER INSERT ON sale
FOR EACH ROW EXECUTE FUNCTION update_best_store();
-- Тригери для контролю місткості 
CREATE FUNCTION check_department_capacity() RETURNS trigger AS $$
DECLARE
    v_capacity INT;
    v_total    INT;
BEGIN
    SELECT capacity INTO v_capacity
    FROM department
    WHERE department_id = NEW.department_id
    FOR UPDATE;

    SELECT COALESCE(SUM(quantity), 0) INTO v_total
    FROM stock
    WHERE department_id = NEW.department_id
      AND magazine_id <> NEW.magazine_id;   -- без поточного рядка

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

-- Тригер для зворотньої перевірки капасіті
-- щоб не було можливості зменшити капасіті відділу, якщо поточна к-сть журналів не дозволяє
CREATE FUNCTION check_capacity_not_below_stock() RETURNS trigger AS $$
BEGIN
    IF (SELECT COALESCE(SUM(quantity),0) FROM stock
        WHERE department_id = NEW.department_id) > NEW.capacity THEN
        RAISE EXCEPTION 'Нова місткість менша за поточну кількість журналів';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_department_capacity
BEFORE UPDATE OF capacity ON department
FOR EACH ROW EXECUTE FUNCTION check_capacity_not_below_stock();

