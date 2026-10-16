-- Triggers.

-- 1. Audit fields: every insert and update stores the time of the change
--    and the staff user from app.current_user_id (see fn_current_staff_id).
CREATE OR REPLACE FUNCTION trg_set_audit_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    NEW.updated_by := fn_current_staff_id();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_staff_users_audit
    BEFORE INSERT OR UPDATE ON staff_users
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

CREATE TRIGGER trg_authors_audit
    BEFORE INSERT OR UPDATE ON authors
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

CREATE TRIGGER trg_books_audit
    BEFORE INSERT OR UPDATE ON books
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

CREATE TRIGGER trg_book_copies_audit
    BEFORE INSERT OR UPDATE ON book_copies
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

CREATE TRIGGER trg_readers_audit
    BEFORE INSERT OR UPDATE ON readers
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

CREATE TRIGGER trg_loans_audit
    BEFORE INSERT OR UPDATE ON loans
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

CREATE TRIGGER trg_services_audit
    BEFORE INSERT OR UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

CREATE TRIGGER trg_service_orders_audit
    BEFORE INSERT OR UPDATE ON service_orders
    FOR EACH ROW EXECUTE FUNCTION trg_set_audit_fields();

-- 2. Soft delete only: a physical DELETE on these tables fails.
CREATE OR REPLACE FUNCTION trg_prevent_hard_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Hard delete from % is not allowed, use soft delete (is_deleted = TRUE)', TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER trg_staff_users_no_delete
    BEFORE DELETE ON staff_users
    FOR EACH ROW EXECUTE FUNCTION trg_prevent_hard_delete();

CREATE TRIGGER trg_authors_no_delete
    BEFORE DELETE ON authors
    FOR EACH ROW EXECUTE FUNCTION trg_prevent_hard_delete();

CREATE TRIGGER trg_books_no_delete
    BEFORE DELETE ON books
    FOR EACH ROW EXECUTE FUNCTION trg_prevent_hard_delete();

CREATE TRIGGER trg_book_copies_no_delete
    BEFORE DELETE ON book_copies
    FOR EACH ROW EXECUTE FUNCTION trg_prevent_hard_delete();

CREATE TRIGGER trg_readers_no_delete
    BEFORE DELETE ON readers
    FOR EACH ROW EXECUTE FUNCTION trg_prevent_hard_delete();

CREATE TRIGGER trg_services_no_delete
    BEFORE DELETE ON services
    FOR EACH ROW EXECUTE FUNCTION trg_prevent_hard_delete();

-- 3. Copy status follows loans: a new loan marks the copy 'loaned',
--    a return puts it back to 'available'.
CREATE OR REPLACE FUNCTION trg_sync_copy_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.returned_at IS NULL THEN
        UPDATE book_copies
        SET status = 'loaned'
        WHERE id = NEW.copy_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.returned_at IS NULL AND NEW.returned_at IS NOT NULL THEN
        UPDATE book_copies
        SET status = 'available'
        WHERE id = NEW.copy_id
          AND status = 'loaned';
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_loans_sync_copy_status
    AFTER INSERT OR UPDATE OF returned_at ON loans
    FOR EACH ROW EXECUTE FUNCTION trg_sync_copy_status();
