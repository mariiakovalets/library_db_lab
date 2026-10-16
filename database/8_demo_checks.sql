-- Demo of every programmable object. Runs inside one transaction and rolls it back,
-- so the data stays as 7_seed_data.sql left it.
--   psql -h localhost -U postgres -d library_lab -f database/8_demo_checks.sql
\pset pager off
\set ON_ERROR_STOP on

BEGIN;

-- changes below are recorded as made by librarian 2
SELECT set_config('app.current_user_id', '2', true);

\echo '--- 1. Trigger trg_prevent_hard_delete: DELETE fails'
DO $$
BEGIN
    DELETE FROM books WHERE id = 7;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error: %', SQLERRM;
END;
$$;

\echo '--- 2. sp_soft_delete_book refuses a book with copies on loan (book 1 is with reader 1)'
DO $$
BEGIN
    CALL sp_soft_delete_book(1);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error: %', SQLERRM;
END;
$$;

\echo '--- 3. sp_soft_delete_book on book 7: it disappears from vw_book_catalog, the row stays'
CALL sp_soft_delete_book(7);
SELECT count(*) AS in_catalog FROM vw_book_catalog WHERE id = 7;
SELECT id, title, is_deleted, updated_at IS NOT NULL AS has_updated_at, updated_by FROM books WHERE id = 7;
SELECT inventory_number, status, is_deleted FROM book_copies WHERE book_id = 7;

\echo '--- 4. fn_reader_can_borrow: reader 4 has no membership, 5 owes a fine, 6 holds an overdue book'
SELECT reader_id, full_name, can_borrow FROM vw_reader_balance ORDER BY reader_id;

\echo '--- 5. sp_issue_loan refuses reader 5 (unpaid fine)'
DO $$
DECLARE
    v_id INTEGER;
BEGIN
    CALL sp_issue_loan(5, 2, v_id);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error: %', SQLERRM;
END;
$$;

\echo '--- 6. sp_issue_loan to reader 2 (copy 9, Московіада, reserved by this reader)'
CALL sp_issue_loan(2, 9, NULL);
CALL sp_fulfill_reservation(2, 5);
\echo 'trigger trg_loans_sync_copy_status set the copy to loaned:'
SELECT id, inventory_number, status, updated_by FROM book_copies WHERE id = 9;
SELECT loan_id, reader_name, title, due_date, days_left FROM vw_active_loans WHERE reader_id = 2;
SELECT book_id, status FROM reservations WHERE reader_id = 2;

\echo '--- 7. sp_return_loan on the overdue loan 4 creates a fine, sp_pay_fine pays it'
CALL sp_return_loan(4, NULL) \gset
SELECT f.id AS fine_id, f.amount, f.reason, f.status FROM fines f WHERE f.loan_id = 4;
SELECT status FROM book_copies WHERE id = 4;
CALL sp_pay_fine(:p_fine_id, 'card', NULL);
SELECT id, amount, method, received_by, fine_id FROM payments WHERE fine_id IS NOT NULL;

\echo '--- 8. sp_order_service: reading room needs a time, then a valid order and its payment'
DO $$
DECLARE
    v_id INTEGER;
BEGIN
    CALL sp_order_service(2, 3, 2, NULL, v_id);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error: %', SQLERRM;
END;
$$;
CALL sp_order_service(2, 3, 2, now() + INTERVAL '2 days', NULL) \gset
CALL sp_pay_service_order(:p_order_id, 'cash', NULL);
SELECT order_id, reader_name, service_name, quantity, total_price, status, is_paid FROM vw_service_orders ORDER BY order_id;

\echo '--- 9. sp_buy_membership for reader 4 (expired), then the reader can borrow again'
CALL sp_buy_membership(4, 1, 'card', NULL);
SELECT reader_id, plan_name, membership_end_date, can_borrow FROM vw_reader_balance WHERE reader_id = 4;

\echo '--- 10. sp_create_reader, sp_soft_delete_reader; the same email can be used again after delete'
CALL sp_create_reader('LC-0100', 'Тестовий Читач', 'Test@Example.com', '+380500000000', '2000-01-01', NULL) \gset
DO $$
DECLARE
    v_id INTEGER;
BEGIN
    CALL sp_create_reader('LC-0101', 'Дубль', 'test@example.com', NULL, NULL, v_id);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error (ux_readers_email_active, case-insensitive): %', SQLERRM;
END;
$$;
CALL sp_soft_delete_reader(:p_reader_id);
CALL sp_create_reader('LC-0101', 'Новий Читач', 'test@example.com', NULL, NULL, NULL);
SELECT library_card_number, email, is_deleted, updated_by FROM readers WHERE library_card_number IN ('LC-0100', 'LC-0101');

\echo '--- 11. sp_create_book, sp_add_book_copy, sp_update_book, fn_search_books'
CALL sp_create_book('978-966-03-9999-9', 'Месопотамія', 2, 3, 2014, 352, ARRAY[3], NULL) \gset
CALL sp_add_book_copy(:p_book_id, 'INV-0099', NULL);
CALL sp_update_book(:p_book_id, 'Месопотамія (2-ге вид.)', 2, 3, 2015, 360);
SELECT * FROM fn_search_books('месопотамія');

\echo '--- 12. Indexes in query plans (seq scan off: the demo tables are tiny)'
SET LOCAL enable_seqscan = off;
EXPLAIN (COSTS OFF) SELECT id FROM books WHERE to_tsvector('simple', title) @@ websearch_to_tsquery('simple', 'кобзар');
EXPLAIN (COSTS OFF) SELECT id FROM readers WHERE phone = '+380501112203';
EXPLAIN (COSTS OFF) SELECT count(*) FROM book_copies WHERE book_id = 1 AND status = 'available' AND NOT is_deleted;
EXPLAIN (COSTS OFF) SELECT id FROM loans WHERE reader_id = 1 AND returned_at IS NULL;

ROLLBACK;
