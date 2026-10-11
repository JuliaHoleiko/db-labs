INSERT INTO author (full_name) VALUES
    ('Стен Лі'),
    ('Стів Дітко'),
    ('Френк Міллер'),
    ('Девід Мацукеллі'),
    ('Кацухіро Отомо'),
    ('Ніл Гейман');


INSERT INTO magazine (title, series, publisher, year, isbn) VALUES
    ('Amazing Spider-Man',  'Spider-Man',     'Marvel',      1963, '978-0-7851-1001-1'),
    ('Batman: Year One',    'Batman',         'DC Comics',   1987, '978-1-4012-0752-4'),
    ('Akira',               'Akira',          'Kodansha',    1988, '978-4-0631-0001-7'),
    ('The Sandman',         'Sandman',        'Vertigo',     1989, '978-1-4012-1001-8'),
    ('Fantastic Four',      'Fantastic Four', 'Marvel',      1961, '978-0-7851-1005-5');

INSERT INTO magazine_author (magazine_id, author_id) VALUES
    (1, 1), (1, 2),     -- Spider-Man: Стен Лі, Стів Дітко
    (2, 3), (2, 4),     -- Batman: Френк Міллер, Девід Мацукеллі
    (3, 5),             -- Akira: Кацухіро Отомо
    (4, 6),             -- Sandman: Ніл Гейман
    (5, 1);             -- Fantastic Four: Стен Лі


INSERT INTO store (name, address) VALUES
    ('Комікс-Центр',  'Львів, вул. Руська, 10'),
    ('Світ Журналів', 'Київ, вул. Хрещатик, 22'),
    ('Манга Хаб',     'Одеса, вул. Дерибасівська, 5');


INSERT INTO department (store_id, dept_number, name, capacity) VALUES
    (1, 1, 'Супергерої',            200),   -- id 1
    (1, 2, 'Манга',                 150),   -- id 2
    (2, 1, 'Американські комікси',  300),   -- id 3
    (2, 2, 'Журнали',               100),   -- id 4
    (3, 1, 'Манга та аніме',        250);   -- id 5


INSERT INTO stock (department_id, magazine_id, quantity) VALUES
    (1, 1, 3),      -- Spider-Man у відділі "Супергерої" (Комікс-Центр)
    (1, 2, 10),     -- Batman
    (2, 3, 12),     -- Akira у відділі "Манга" (Комікс-Центр)
    (3, 1, 2),      -- Spider-Man у "Світ Журналів"
    (3, 4, 7),      -- Sandman
    (4, 4, 4),      -- Sandman у відділі "Журнали"
    (5, 3, 8),
    (1, 5, 10),
    (2, 4, 10), 
    (3, 3, 5);       -- Akira у "Манга Хаб"


INSERT INTO customer (email, full_name, birth_date, address, phone) VALUES
    ('olena.kovalenko@example.com',  'Коваленко Олена Петрівна',    '2001-05-14', 'Львів, вул. Зелена, 15',      '+380501112233'),
    ('andriy.shevchenko@example.com','Шевченко Андрій Іванович',    '1995-11-02', 'Київ, вул. Сагайдачного, 8',  '+380672223344'),
    ('maria.bondar@example.com',     'Бондар Марія Олегівна',       '2008-03-21', 'Одеса, вул. Пушкінська, 12',  '+380633334455'),
    ('dmytro.melnyk@example.com',    'Мельник Дмитро Сергійович',   '1988-07-30', 'Львів, вул. Личаківська, 40', '+380504445566'),
    ('sofiia.tkachenko@example.com', 'Ткаченко Софія Андріївна',    '2010-01-09', 'Київ, вул. Липська, 3',       '+380965556677');


INSERT INTO sale (customer_id, department_id, magazine_id, sale_date) VALUES
    (1, 1, 1, '2026-08-10'),
    (1, 1, 2, '2026-09-20'),
    (1, 2, 3, '2026-10-01'),
    (2, 2, 3, '2026-07-15'),
    (2, 2, 4, '2026-09-28'),
    (3, 3, 4, '2026-10-02'),
    (4, 1, 1, '2026-06-01'),
    (4, 1, 5, '2026-08-25'),
    (5, 3, 3, '2026-10-03');
