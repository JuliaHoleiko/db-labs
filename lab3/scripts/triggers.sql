-- 1. Тригер для обчислення улюбленого магазину
CREATE OR REPLACE FUNCTION recalc_best_store(p_customer INT) RETURNS void AS $$
BEGIN
    UPDATE customer
    SET best_store_id = (
        SELECT d.store_id
        FROM sale s
        JOIN department d ON d.department_id = s.department_id
        WHERE s.customer_id = p_customer
        GROUP BY d.store_id
        ORDER BY COUNT(*) DESC, MAX(s.sale_date) DESC, MAX(s.sale_id) DESC 
        LIMIT 1
    )
    WHERE customer_id = p_customer;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_best_store() RETURNS trigger AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM recalc_best_store(NEW.customer_id);
    END IF;
    IF TG_OP = 'DELETE'
       OR (TG_OP = 'UPDATE' AND OLD.customer_id IS DISTINCT FROM NEW.customer_id) THEN
        PERFORM recalc_best_store(OLD.customer_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sale_best_store ON sale;
CREATE TRIGGER trg_sale_best_store
AFTER INSERT OR DELETE OR UPDATE OF customer_id, department_id, sale_date ON sale
FOR EACH ROW EXECUTE FUNCTION trg_best_store();


-- 2. Тригери для контролю місткості
CREATE OR REPLACE FUNCTION check_department_capacity() RETURNS trigger AS $$
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
      AND magazine_id <> NEW.magazine_id;

    IF v_total + NEW.quantity > v_capacity THEN
        RAISE EXCEPTION
            'Відділ % переповнений: місткість %, буде %',
            NEW.department_id, v_capacity, v_total + NEW.quantity;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_capacity ON stock;
CREATE TRIGGER trg_stock_capacity
BEFORE INSERT OR UPDATE OF quantity, department_id ON stock
FOR EACH ROW EXECUTE FUNCTION check_department_capacity();


-- 3. Тригер для зворотньої перевірки капасіті
CREATE OR REPLACE FUNCTION check_capacity_not_below_stock() RETURNS trigger AS $$
BEGIN
    IF (SELECT COALESCE(SUM(quantity),0) FROM stock
        WHERE department_id = NEW.department_id) > NEW.capacity THEN
        RAISE EXCEPTION 'Нова місткість менша за поточну кількість журналів';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_department_capacity ON department;
CREATE TRIGGER trg_department_capacity
BEFORE UPDATE OF capacity ON department
FOR EACH ROW EXECUTE FUNCTION check_capacity_not_below_stock();


-- 4. Тригер на зменшення кількості журналів після покупки
CREATE OR REPLACE FUNCTION sale_decrease_stock() RETURNS trigger AS $$
BEGIN
    UPDATE stock
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

DROP TRIGGER IF EXISTS trg_sale_stock ON sale;
CREATE TRIGGER trg_sale_stock
BEFORE INSERT ON sale
FOR EACH ROW EXECUTE FUNCTION sale_decrease_stock();


-- 5. Тригер на повернення журналів у stock у випадку видалення
CREATE OR REPLACE FUNCTION sale_restore_stock() RETURNS trigger AS $$
BEGIN
    UPDATE stock SET quantity = quantity + 1
    WHERE department_id = OLD.department_id AND magazine_id = OLD.magazine_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sale_restore ON sale;
CREATE TRIGGER trg_sale_restore
AFTER DELETE ON sale
FOR EACH ROW EXECUTE FUNCTION sale_restore_stock();


-- 6. Тригер на зміну відділу або журналу в існуючому продажу
CREATE OR REPLACE FUNCTION sale_update_stock() RETURNS trigger AS $$
BEGIN
    UPDATE stock
    SET quantity = quantity + 1
    WHERE department_id = OLD.department_id
      AND magazine_id   = OLD.magazine_id;

    UPDATE stock
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

DROP TRIGGER IF EXISTS trg_sale_update_stock ON sale;
CREATE TRIGGER trg_sale_update_stock
BEFORE UPDATE OF department_id, magazine_id ON sale
FOR EACH ROW
WHEN (OLD.department_id IS DISTINCT FROM NEW.department_id
      OR OLD.magazine_id IS DISTINCT FROM NEW.magazine_id)
EXECUTE FUNCTION sale_update_stock();