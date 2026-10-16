-- User-defined functions.

-- Id of the staff user who makes the current change.
-- The application sets it once per transaction:
--   SELECT set_config('app.current_user_id', '2', true);
-- Triggers and procedures read it, so callers do not pass the user to every call.
CREATE OR REPLACE FUNCTION fn_current_staff_id()
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::INTEGER;
$$;

-- Fine for a loan: 5.00 UAH for each day past the due date.
-- For a returned book it counts up to the return date, otherwise up to today.
CREATE OR REPLACE FUNCTION fn_calculate_fine(p_loan_id INTEGER)
RETURNS NUMERIC(10, 2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_due_date     DATE;
    v_returned_at  TIMESTAMPTZ;
    v_days_overdue INTEGER;
BEGIN
    SELECT due_date, returned_at
    INTO v_due_date, v_returned_at
    FROM loans
    WHERE id = p_loan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % not found', p_loan_id;
    END IF;

    v_days_overdue := COALESCE(v_returned_at::DATE, current_date) - v_due_date;

    IF v_days_overdue <= 0 THEN
        RETURN 0;
    END IF;

    RETURN v_days_overdue * 5.00;
END;
$$;

-- A reader can borrow a book when all of these hold:
-- the reader is not deleted, has a membership valid today,
-- holds fewer books than the plan allows, holds no overdue books and has no unpaid fines.
CREATE OR REPLACE FUNCTION fn_reader_can_borrow(p_reader_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_max_books    INTEGER;
    v_active_loans INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM readers WHERE id = p_reader_id AND NOT is_deleted) THEN
        RETURN FALSE;
    END IF;

    SELECT mp.max_books
    INTO v_max_books
    FROM reader_memberships rm
    JOIN membership_plans mp ON mp.id = rm.plan_id
    WHERE rm.reader_id = p_reader_id
      AND current_date BETWEEN rm.start_date AND rm.end_date
    ORDER BY rm.end_date DESC
    LIMIT 1;

    IF v_max_books IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT count(*)
    INTO v_active_loans
    FROM loans
    WHERE reader_id = p_reader_id
      AND returned_at IS NULL;

    IF v_active_loans >= v_max_books THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM loans
        WHERE reader_id = p_reader_id
          AND returned_at IS NULL
          AND due_date < current_date
    ) THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM fines f
        JOIN loans l ON l.id = f.loan_id
        WHERE l.reader_id = p_reader_id
          AND f.status = 'unpaid'
    ) THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

-- Number of copies of a book that are on the shelf right now.
CREATE OR REPLACE FUNCTION fn_available_copies_count(p_book_id INTEGER)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT count(*)::INTEGER
    FROM book_copies
    WHERE book_id = p_book_id
      AND status = 'available'
      AND NOT is_deleted;
$$;

-- Full-text search over book titles. Uses the GIN index ix_books_title_fts.
-- Accepts web-style queries: "жадан інтернат", "кобзар OR пісня", "-sapiens".
CREATE OR REPLACE FUNCTION fn_search_books(p_query TEXT)
RETURNS TABLE (
    book_id          INTEGER,
    isbn             VARCHAR,
    title            VARCHAR,
    authors          TEXT,
    available_copies INTEGER,
    rank             REAL
)
LANGUAGE sql
STABLE
AS $$
    SELECT b.id,
           b.isbn,
           b.title,
           COALESCE(string_agg(a.full_name, ', ' ORDER BY a.full_name), '') AS authors,
           fn_available_copies_count(b.id),
           ts_rank(to_tsvector('simple', b.title), websearch_to_tsquery('simple', p_query)) AS rank
    FROM books b
    LEFT JOIN book_authors ba ON ba.book_id = b.id
    LEFT JOIN authors a ON a.id = ba.author_id AND NOT a.is_deleted
    WHERE NOT b.is_deleted
      AND to_tsvector('simple', b.title) @@ websearch_to_tsquery('simple', p_query)
    GROUP BY b.id
    ORDER BY rank DESC, b.title;
$$;
