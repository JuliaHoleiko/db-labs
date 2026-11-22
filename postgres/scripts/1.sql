SET search_path TO bookstore_app, public;

-- 1. Бізнес-процедура оформлення продажу на касі
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