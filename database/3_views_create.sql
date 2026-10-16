-- Views. The application reads data only through these views and fn_search_books.

-- Catalog of books that are not deleted, with authors and copy counts.
CREATE OR REPLACE VIEW vw_book_catalog AS
SELECT b.id,
       b.isbn,
       b.title,
       b.publish_year,
       b.pages_count,
       b.publisher_id,
       p.name AS publisher,
       b.genre_id,
       g.name AS genre,
       COALESCE(string_agg(a.full_name, ', ' ORDER BY a.full_name), '') AS authors,
       (SELECT count(*)::INTEGER
        FROM book_copies c
        WHERE c.book_id = b.id AND NOT c.is_deleted) AS total_copies,
       fn_available_copies_count(b.id) AS available_copies,
       b.updated_at,
       b.updated_by
FROM books b
JOIN publishers p ON p.id = b.publisher_id
JOIN genres g ON g.id = b.genre_id
LEFT JOIN book_authors ba ON ba.book_id = b.id
LEFT JOIN authors a ON a.id = ba.author_id AND NOT a.is_deleted
WHERE NOT b.is_deleted
GROUP BY b.id, p.name, g.name;

-- Copies on the shelf that can be issued.
CREATE OR REPLACE VIEW vw_available_copies AS
SELECT c.id AS copy_id,
       c.inventory_number,
       c.book_id,
       b.title,
       b.isbn
FROM book_copies c
JOIN books b ON b.id = c.book_id
WHERE c.status = 'available'
  AND NOT c.is_deleted
  AND NOT b.is_deleted;

-- Books that readers hold right now.
CREATE OR REPLACE VIEW vw_active_loans AS
SELECT l.id AS loan_id,
       l.reader_id,
       r.full_name AS reader_name,
       r.library_card_number,
       l.copy_id,
       c.inventory_number,
       b.id AS book_id,
       b.title,
       l.issued_at,
       l.due_date,
       l.due_date - current_date AS days_left
FROM loans l
JOIN readers r ON r.id = l.reader_id
JOIN book_copies c ON c.id = l.copy_id
JOIN books b ON b.id = c.book_id
WHERE l.returned_at IS NULL;

-- Active loans past their due date, with the fine the reader will owe on return today.
CREATE OR REPLACE VIEW vw_overdue_loans AS
SELECT loan_id,
       reader_id,
       reader_name,
       library_card_number,
       inventory_number,
       title,
       issued_at,
       due_date,
       current_date - due_date AS days_overdue,
       fn_calculate_fine(loan_id) AS expected_fine
FROM vw_active_loans
WHERE due_date < current_date;

-- Reader card: current membership, books on hand, debt and whether the reader can borrow.
CREATE OR REPLACE VIEW vw_reader_balance AS
SELECT r.id AS reader_id,
       r.library_card_number,
       r.full_name,
       r.email,
       r.phone,
       m.plan_name,
       m.end_date AS membership_end_date,
       (SELECT count(*)::INTEGER
        FROM loans l
        WHERE l.reader_id = r.id AND l.returned_at IS NULL) AS active_loans,
       COALESCE((SELECT sum(f.amount)
                 FROM fines f
                 JOIN loans l ON l.id = f.loan_id
                 WHERE l.reader_id = r.id AND f.status = 'unpaid'), 0) AS unpaid_fines,
       fn_reader_can_borrow(r.id) AS can_borrow,
       r.updated_at,
       r.updated_by
FROM readers r
LEFT JOIN LATERAL (
    SELECT mp.name AS plan_name, rm.end_date
    FROM reader_memberships rm
    JOIN membership_plans mp ON mp.id = rm.plan_id
    WHERE rm.reader_id = r.id
      AND current_date BETWEEN rm.start_date AND rm.end_date
    ORDER BY rm.end_date DESC
    LIMIT 1
) m ON TRUE
WHERE NOT r.is_deleted;

-- Additional services that can be ordered.
CREATE OR REPLACE VIEW vw_service_catalog AS
SELECT id,
       name,
       description,
       price,
       unit,
       requires_schedule
FROM services
WHERE NOT is_deleted;

-- Service orders with the reader, the service and the payment state.
CREATE OR REPLACE VIEW vw_service_orders AS
SELECT o.id AS order_id,
       o.reader_id,
       r.full_name AS reader_name,
       o.service_id,
       s.name AS service_name,
       o.quantity,
       s.unit,
       o.total_price,
       o.scheduled_at,
       o.status,
       EXISTS (SELECT 1 FROM payments p WHERE p.service_order_id = o.id) AS is_paid,
       o.created_at
FROM service_orders o
JOIN readers r ON r.id = o.reader_id
JOIN services s ON s.id = o.service_id;
