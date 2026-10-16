-- Stored procedures. The application changes data only through these procedures.
-- Procedures that create a row return its id through the last INOUT parameter:
--   CALL sp_create_reader('LC-0100', 'Name', NULL, NULL, NULL, NULL);

--  Books 

CREATE OR REPLACE PROCEDURE sp_create_book(
    p_isbn         VARCHAR,
    p_title        VARCHAR,
    p_publisher_id INTEGER,
    p_genre_id     INTEGER,
    p_publish_year INTEGER,
    p_pages_count  INTEGER,
    p_author_ids   INTEGER[],
    INOUT p_book_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_author_ids IS NULL OR cardinality(p_author_ids) = 0 THEN
        RAISE EXCEPTION 'A book needs at least one author';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM unnest(p_author_ids) AS x(author_id)
        WHERE NOT EXISTS (SELECT 1 FROM authors a WHERE a.id = x.author_id AND NOT a.is_deleted)
    ) THEN
        RAISE EXCEPTION 'One of the authors % does not exist or is deleted', p_author_ids;
    END IF;

    INSERT INTO books (isbn, title, publisher_id, genre_id, publish_year, pages_count)
    VALUES (p_isbn, p_title, p_publisher_id, p_genre_id, p_publish_year, p_pages_count)
    RETURNING id INTO p_book_id;

    INSERT INTO book_authors (book_id, author_id)
    SELECT DISTINCT p_book_id, x
    FROM unnest(p_author_ids) AS x;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_update_book(
    p_book_id      INTEGER,
    p_title        VARCHAR,
    p_publisher_id INTEGER,
    p_genre_id     INTEGER,
    p_publish_year INTEGER,
    p_pages_count  INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE books
    SET title        = p_title,
        publisher_id = p_publisher_id,
        genre_id     = p_genre_id,
        publish_year = p_publish_year,
        pages_count  = p_pages_count
    WHERE id = p_book_id
      AND NOT is_deleted;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book % not found', p_book_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_add_book_copy(
    p_book_id          INTEGER,
    p_inventory_number VARCHAR,
    INOUT p_copy_id    INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM books WHERE id = p_book_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Book % not found', p_book_id;
    END IF;

    INSERT INTO book_copies (book_id, inventory_number)
    VALUES (p_book_id, p_inventory_number)
    RETURNING id INTO p_copy_id;
END;
$$;

-- Soft delete of a book: hides the book and its copies, cancels its reservations.
-- Refuses while any copy is with a reader.
CREATE OR REPLACE PROCEDURE sp_soft_delete_book(p_book_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM books WHERE id = p_book_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Book % not found', p_book_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM loans l
        JOIN book_copies c ON c.id = l.copy_id
        WHERE c.book_id = p_book_id
          AND l.returned_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Book % has copies on loan, it cannot be deleted', p_book_id;
    END IF;

    UPDATE book_copies
    SET is_deleted = TRUE,
        status     = 'written_off'
    WHERE book_id = p_book_id
      AND NOT is_deleted;

    UPDATE reservations
    SET status = 'cancelled'
    WHERE book_id = p_book_id
      AND status = 'active';

    UPDATE books
    SET is_deleted = TRUE
    WHERE id = p_book_id;
END;
$$;

--  Readers 

CREATE OR REPLACE PROCEDURE sp_create_reader(
    p_library_card_number VARCHAR,
    p_full_name           VARCHAR,
    p_email               VARCHAR,
    p_phone               VARCHAR,
    p_birth_date          DATE,
    INOUT p_reader_id     INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO readers (library_card_number, full_name, email, phone, birth_date)
    VALUES (p_library_card_number, p_full_name, p_email, p_phone, p_birth_date)
    RETURNING id INTO p_reader_id;
END;
$$;

-- Soft delete of a reader: refuses while the reader holds books or owes fines,
-- cancels the reader's reservations and service orders that are not done yet.
CREATE OR REPLACE PROCEDURE sp_soft_delete_reader(p_reader_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM readers WHERE id = p_reader_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Reader % not found', p_reader_id;
    END IF;

    IF EXISTS (SELECT 1 FROM loans WHERE reader_id = p_reader_id AND returned_at IS NULL) THEN
        RAISE EXCEPTION 'Reader % still holds books, return them first', p_reader_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM fines f
        JOIN loans l ON l.id = f.loan_id
        WHERE l.reader_id = p_reader_id
          AND f.status = 'unpaid'
    ) THEN
        RAISE EXCEPTION 'Reader % has unpaid fines', p_reader_id;
    END IF;

    UPDATE reservations
    SET status = 'cancelled'
    WHERE reader_id = p_reader_id
      AND status = 'active';

    UPDATE service_orders
    SET status = 'cancelled'
    WHERE reader_id = p_reader_id
      AND status = 'new';

    UPDATE readers
    SET is_deleted = TRUE
    WHERE id = p_reader_id;
END;
$$;

-- Sells a membership and records the payment. A new membership starts the day after
-- the current one ends, so buying early does not waste days.
CREATE OR REPLACE PROCEDURE sp_buy_membership(
    p_reader_id         INTEGER,
    p_plan_id           INTEGER,
    p_method            VARCHAR,
    INOUT p_membership_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_staff_id   INTEGER := fn_current_staff_id();
    v_price      NUMERIC(10, 2);
    v_duration   INTEGER;
    v_start_date DATE;
BEGIN
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Staff user is not set (app.current_user_id)';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM readers WHERE id = p_reader_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Reader % not found', p_reader_id;
    END IF;

    SELECT price, duration_days
    INTO v_price, v_duration
    FROM membership_plans
    WHERE id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Membership plan % not found', p_plan_id;
    END IF;

    SELECT COALESCE(max(end_date) + 1, current_date)
    INTO v_start_date
    FROM reader_memberships
    WHERE reader_id = p_reader_id
      AND end_date >= current_date;

    INSERT INTO reader_memberships (reader_id, plan_id, start_date, end_date)
    VALUES (p_reader_id, p_plan_id, v_start_date, v_start_date + v_duration)
    RETURNING id INTO p_membership_id;

    INSERT INTO payments (reader_id, amount, method, received_by, reader_membership_id)
    VALUES (p_reader_id, v_price, p_method, v_staff_id, p_membership_id);
END;
$$;

--  Circulation 

-- Issues one copy to a reader. The due date comes from the reader's plan.
-- The copy status changes to 'loaned' in trigger trg_loans_sync_copy_status.
CREATE OR REPLACE PROCEDURE sp_issue_loan(
    p_reader_id   INTEGER,
    p_copy_id     INTEGER,
    INOUT p_loan_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_staff_id   INTEGER := fn_current_staff_id();
    v_status     VARCHAR;
    v_is_deleted BOOLEAN;
    v_loan_days  INTEGER;
BEGIN
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Staff user is not set (app.current_user_id)';
    END IF;

    IF NOT fn_reader_can_borrow(p_reader_id) THEN
        RAISE EXCEPTION 'Reader % cannot borrow: needs a valid membership, a free slot under the plan limit, no overdue books and no unpaid fines', p_reader_id;
    END IF;

    -- lock the copy so two librarians cannot issue it at the same time
    SELECT status, is_deleted
    INTO v_status, v_is_deleted
    FROM book_copies
    WHERE id = p_copy_id
    FOR UPDATE;

    IF NOT FOUND OR v_is_deleted THEN
        RAISE EXCEPTION 'Copy % not found', p_copy_id;
    END IF;

    IF v_status <> 'available' THEN
        RAISE EXCEPTION 'Copy % is not available (status: %)', p_copy_id, v_status;
    END IF;

    SELECT mp.loan_days
    INTO v_loan_days
    FROM reader_memberships rm
    JOIN membership_plans mp ON mp.id = rm.plan_id
    WHERE rm.reader_id = p_reader_id
      AND current_date BETWEEN rm.start_date AND rm.end_date
    ORDER BY rm.end_date DESC
    LIMIT 1;

    INSERT INTO loans (copy_id, reader_id, issued_by, due_date)
    VALUES (p_copy_id, p_reader_id, v_staff_id, current_date + v_loan_days)
    RETURNING id INTO p_loan_id;
END;
$$;

-- Marks the reader's active reservation of a book as fulfilled. Does nothing if there is none.
CREATE OR REPLACE PROCEDURE sp_fulfill_reservation(p_reader_id INTEGER, p_book_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE reservations
    SET status = 'fulfilled'
    WHERE reader_id = p_reader_id
      AND book_id = p_book_id
      AND status = 'active';
END;
$$;

-- Reserves a book for 3 days.
CREATE OR REPLACE PROCEDURE sp_reserve_book(
    p_reader_id          INTEGER,
    p_book_id            INTEGER,
    INOUT p_reservation_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM readers WHERE id = p_reader_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Reader % not found', p_reader_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM books WHERE id = p_book_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Book % not found', p_book_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reservations
        WHERE reader_id = p_reader_id
          AND book_id = p_book_id
          AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Reader % already has an active reservation for book %', p_reader_id, p_book_id;
    END IF;

    INSERT INTO reservations (book_id, reader_id, expires_at)
    VALUES (p_book_id, p_reader_id, now() + INTERVAL '3 days')
    RETURNING id INTO p_reservation_id;
END;
$$;

-- Closes a loan. If the book is late, creates a fine and returns its id (otherwise NULL).
-- The copy goes back to 'available' in trigger trg_loans_sync_copy_status.
CREATE OR REPLACE PROCEDURE sp_return_loan(
    p_loan_id     INTEGER,
    INOUT p_fine_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_returned_at TIMESTAMPTZ;
    v_due_date    DATE;
    v_amount      NUMERIC(10, 2);
BEGIN
    SELECT returned_at, due_date
    INTO v_returned_at, v_due_date
    FROM loans
    WHERE id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % not found', p_loan_id;
    END IF;

    IF v_returned_at IS NOT NULL THEN
        RAISE EXCEPTION 'Loan % is already closed', p_loan_id;
    END IF;

    UPDATE loans
    SET returned_at = now()
    WHERE id = p_loan_id;

    v_amount := fn_calculate_fine(p_loan_id);
    p_fine_id := NULL;

    IF v_amount > 0 THEN
        INSERT INTO fines (loan_id, amount, reason)
        VALUES (p_loan_id, v_amount, format('Returned %s days late', current_date - v_due_date))
        RETURNING id INTO p_fine_id;
    END IF;
END;
$$;

--  Payments 

CREATE OR REPLACE PROCEDURE sp_pay_fine(
    p_fine_id      INTEGER,
    p_method       VARCHAR,
    INOUT p_payment_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_staff_id  INTEGER := fn_current_staff_id();
    v_amount    NUMERIC(10, 2);
    v_status    VARCHAR;
    v_reader_id INTEGER;
BEGIN
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Staff user is not set (app.current_user_id)';
    END IF;

    SELECT f.amount, f.status, l.reader_id
    INTO v_amount, v_status, v_reader_id
    FROM fines f
    JOIN loans l ON l.id = f.loan_id
    WHERE f.id = p_fine_id
    FOR UPDATE OF f;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fine % not found', p_fine_id;
    END IF;

    IF v_status = 'paid' THEN
        RAISE EXCEPTION 'Fine % is already paid', p_fine_id;
    END IF;

    INSERT INTO payments (reader_id, amount, method, received_by, fine_id)
    VALUES (v_reader_id, v_amount, p_method, v_staff_id, p_fine_id)
    RETURNING id INTO p_payment_id;

    UPDATE fines
    SET status = 'paid'
    WHERE id = p_fine_id;
END;
$$;

--  Additional services 

-- Creates an order for a service. Services that need booking require a future date and time.
CREATE OR REPLACE PROCEDURE sp_order_service(
    p_reader_id    INTEGER,
    p_service_id   INTEGER,
    p_quantity     INTEGER,
    p_scheduled_at TIMESTAMPTZ,
    INOUT p_order_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_price             NUMERIC(10, 2);
    v_requires_schedule BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM readers WHERE id = p_reader_id AND NOT is_deleted) THEN
        RAISE EXCEPTION 'Reader % not found', p_reader_id;
    END IF;

    SELECT price, requires_schedule
    INTO v_price, v_requires_schedule
    FROM services
    WHERE id = p_service_id
      AND NOT is_deleted;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service % not found', p_service_id;
    END IF;

    IF v_requires_schedule AND p_scheduled_at IS NULL THEN
        RAISE EXCEPTION 'Service % needs a booking date and time', p_service_id;
    END IF;

    IF p_scheduled_at IS NOT NULL AND p_scheduled_at < now() THEN
        RAISE EXCEPTION 'Booking time % is in the past', p_scheduled_at;
    END IF;

    INSERT INTO service_orders (reader_id, service_id, quantity, total_price, scheduled_at)
    VALUES (p_reader_id, p_service_id, p_quantity, v_price * p_quantity, p_scheduled_at)
    RETURNING id INTO p_order_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_pay_service_order(
    p_order_id     INTEGER,
    p_method       VARCHAR,
    INOUT p_payment_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_staff_id    INTEGER := fn_current_staff_id();
    v_reader_id   INTEGER;
    v_total_price NUMERIC(10, 2);
    v_status      VARCHAR;
BEGIN
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Staff user is not set (app.current_user_id)';
    END IF;

    SELECT reader_id, total_price, status
    INTO v_reader_id, v_total_price, v_status
    FROM service_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service order % not found', p_order_id;
    END IF;

    IF v_status = 'cancelled' THEN
        RAISE EXCEPTION 'Service order % is cancelled', p_order_id;
    END IF;

    IF EXISTS (SELECT 1 FROM payments WHERE service_order_id = p_order_id) THEN
        RAISE EXCEPTION 'Service order % is already paid', p_order_id;
    END IF;

    INSERT INTO payments (reader_id, amount, method, received_by, service_order_id)
    VALUES (v_reader_id, v_total_price, p_method, v_staff_id, p_order_id)
    RETURNING id INTO p_payment_id;
END;
$$;
