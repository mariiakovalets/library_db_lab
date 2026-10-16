-- Test data for the demo. People are fictional, ISBNs and editions are illustrative.
-- Ids follow insertion order on a fresh schema (run 0_reset.sql first).
-- Dates are relative to today, so overdue and active loans stay that way on any run date.

INSERT INTO roles (name) VALUES ('admin'), ('librarian');

INSERT INTO staff_users (role_id, full_name, email) VALUES
    (1, 'Олена Кравець', 'olena.kravets@library.test'),  -- 1
    (2, 'Іван Мельник',  'ivan.melnyk@library.test'),    -- 2
    (2, 'Софія Бондар',  'sofiia.bondar@library.test');  -- 3

-- from here on every change is recorded as made by staff user 1
SELECT set_config('app.current_user_id', '1', false);

INSERT INTO publishers (name, address, founded_year) VALUES
    ('А-ба-ба-га-ла-ма-га',        'Київ',  1992),  -- 1
    ('Фоліо',                      'Харків', 1991), -- 2
    ('Видавництво Старого Лева',   'Львів',  2001), -- 3
    ('Наш Формат',                 'Київ',  2011);  -- 4

INSERT INTO authors (full_name, birth_year) VALUES
    ('Тарас Шевченко',     1814),  -- 1
    ('Леся Українка',      1871),  -- 2
    ('Сергій Жадан',       1974),  -- 3
    ('Юрій Андрухович',    1960),  -- 4
    ('Ліна Костенко',      1930),  -- 5
    ('Оксана Забужко',     1960),  -- 6
    ('Юваль Ной Харарі',   1976);  -- 7

INSERT INTO genres (name) VALUES
    ('Поезія'),               -- 1
    ('Драма'),                -- 2
    ('Проза'),                -- 3
    ('Науково-популярна');    -- 4

INSERT INTO books (isbn, title, publisher_id, genre_id, publish_year, pages_count) VALUES
    ('978-966-7047-01-1', 'Кобзар',                              1, 1, 2019, 640),  -- 1
    ('978-966-03-0102-2', 'Лісова пісня',                        2, 2, 2018, 192),  -- 2
    ('978-966-03-0103-3', 'Інтернат',                            2, 3, 2017, 336),  -- 3
    ('978-966-03-0104-4', 'Ворошиловград',                       2, 3, 2010, 448),  -- 4
    ('978-966-03-0105-5', 'Московіада',                          2, 3, 2016, 320),  -- 5
    ('978-966-7047-06-6', 'Маруся Чурай',                        1, 1, 2011, 224),  -- 6
    ('978-617-679-07-7',  'Музей покинутих секретів',            3, 3, 2010, 832),  -- 7
    ('978-617-7279-08-8', 'Sapiens. Людство: коротка історія',   4, 4, 2018, 544);  -- 8

INSERT INTO book_authors (book_id, author_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 3), (5, 4), (6, 5), (7, 6), (8, 7);

INSERT INTO book_copies (book_id, inventory_number, acquired_at) VALUES
    (1, 'INV-0001', current_date - 400),  -- 1
    (1, 'INV-0002', current_date - 400),  -- 2
    (1, 'INV-0003', current_date - 100),  -- 3
    (2, 'INV-0004', current_date - 300),  -- 4
    (2, 'INV-0005', current_date - 300),  -- 5
    (3, 'INV-0006', current_date - 250),  -- 6
    (3, 'INV-0007', current_date - 250),  -- 7
    (4, 'INV-0008', current_date - 250),  -- 8
    (5, 'INV-0009', current_date - 200),  -- 9
    (6, 'INV-0010', current_date - 200),  -- 10
    (7, 'INV-0011', current_date - 150),  -- 11
    (8, 'INV-0012', current_date - 90),   -- 12
    (8, 'INV-0013', current_date - 90);   -- 13

INSERT INTO readers (library_card_number, full_name, email, phone, birth_date) VALUES
    ('LC-0001', 'Марія Ткаченко', 'maria.tkachenko@example.com', '+380501112201', '2004-03-12'),  -- 1 student plan
    ('LC-0002', 'Андрій Коваль',  'andrii.koval@example.com',    '+380501112202', '1995-07-21'),  -- 2 standard plan
    ('LC-0003', 'Оксана Литвин',  'oksana.lytvyn@example.com',   '+380501112203', '1988-11-02'),  -- 3 premium plan
    ('LC-0004', 'Дмитро Савчук',  'dmytro.savchuk@example.com',  '+380501112204', '2001-01-30'),  -- 4 membership expired
    ('LC-0005', 'Ірина Мороз',    'iryna.moroz@example.com',     '+380501112205', '1999-05-17'),  -- 5 has an unpaid fine
    ('LC-0006', 'Петро Гнатюк',   'petro.hnatiuk@example.com',   '+380501112206', '2003-09-09');  -- 6 holds an overdue book

INSERT INTO membership_plans (name, price, duration_days, max_books, loan_days) VALUES
    ('Студентський', 50.00,  30,  3, 14),  -- 1
    ('Стандартний',  120.00, 90,  5, 21),  -- 2
    ('Преміум',      300.00, 365, 10, 30); -- 3

INSERT INTO reader_memberships (reader_id, plan_id, start_date, end_date) VALUES
    (1, 1, current_date - 10,  current_date + 20),   -- 1
    (2, 2, current_date - 40,  current_date + 50),   -- 2
    (3, 3, current_date - 100, current_date + 265),  -- 3
    (4, 2, current_date - 130, current_date - 40),   -- 4 expired
    (5, 2, current_date - 45,  current_date + 45),   -- 5
    (6, 1, current_date - 20,  current_date + 10);   -- 6

INSERT INTO payments (reader_id, amount, method, received_by, reader_membership_id) VALUES
    (1, 50.00,  'card', 2, 1),
    (2, 120.00, 'cash', 2, 2),
    (3, 300.00, 'card', 3, 3),
    (4, 120.00, 'cash', 2, 4),
    (5, 120.00, 'card', 3, 5),
    (6, 50.00,  'cash', 2, 6);

-- loans: the trigger marks copies of open loans as 'loaned'
INSERT INTO loans (copy_id, reader_id, issued_by, issued_at, due_date, returned_at) VALUES
    (1,  1, 2, now() - INTERVAL '5 days',  current_date + 9,  NULL),                        -- 1 active
    (6,  2, 2, now() - INTERVAL '30 days', current_date - 9,  now() - INTERVAL '12 days'),  -- 2 returned on time
    (8,  5, 3, now() - INTERVAL '40 days', current_date - 19, now() - INTERVAL '10 days'),  -- 3 returned 9 days late
    (4,  6, 2, now() - INTERVAL '20 days', current_date - 6,  NULL),                        -- 4 active, overdue
    (12, 3, 3, now() - INTERVAL '2 days',  current_date + 28, NULL);                        -- 5 active

INSERT INTO fines (loan_id, amount, reason, status) VALUES
    (3, 45.00, 'Returned 9 days late', 'unpaid');

INSERT INTO reservations (book_id, reader_id, reserved_at, expires_at, status) VALUES
    (5, 2, now() - INTERVAL '1 day', now() + INTERVAL '2 days', 'active'),
    (8, 1, now() - INTERVAL '1 day', now() + INTERVAL '2 days', 'active');

INSERT INTO services (name, description, price, unit, requires_schedule) VALUES
    ('Друк',                         'Чорно-білий друк A4',                                   2.00,   'page',    FALSE),  -- 1
    ('Сканування',                   'Сканування в PDF з відправкою на email',                1.50,   'page',    FALSE),  -- 2
    ('Місце в читальній залі',       'Робоче місце з розеткою і Wi-Fi',                       20.00,  'hour',    TRUE),   -- 3
    ('Міжбібліотечний абонемент',    'Замовлення книги з іншої бібліотеки',                   50.00,  'request', FALSE),  -- 4
    ('Консультація бібліографа',     'Допомога з пошуком джерел і оформленням списку',        100.00, 'hour',    TRUE);   -- 5

INSERT INTO service_orders (reader_id, service_id, quantity, total_price, scheduled_at, status) VALUES
    (1, 1, 20, 40.00, NULL, 'completed'),                                        -- 1 paid
    (3, 3, 3,  60.00, date_trunc('day', now()) + INTERVAL '1 day 10 hours', 'new');  -- 2 not paid yet

INSERT INTO payments (reader_id, amount, method, received_by, service_order_id) VALUES
    (1, 40.00, 'cash', 2, 1);

SELECT set_config('app.current_user_id', '', false);
