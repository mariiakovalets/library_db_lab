-- Indexes. PostgreSQL already creates B-tree indexes for PRIMARY KEY and UNIQUE constraints.

-- B-tree, composite: active loans of a reader (WHERE reader_id = ? AND returned_at IS NULL).
CREATE INDEX ix_loans_reader_returned ON loans (reader_id, returned_at);

-- B-tree, partial (filtered): only copies that can be issued. Serves vw_available_copies
-- and fn_available_copies_count without touching loaned and written-off copies.
CREATE INDEX ix_book_copies_available ON book_copies (book_id)
    WHERE status = 'available' AND NOT is_deleted;

-- B-tree, unique + partial: ISBN must be unique only among books that are not deleted,
-- so a deleted edition can be added again.
CREATE UNIQUE INDEX ux_books_isbn_active ON books (isbn)
    WHERE NOT is_deleted;

-- B-tree, unique + partial + on a function value: email is unique among active readers
-- regardless of letter case.
CREATE UNIQUE INDEX ux_readers_email_active ON readers (lower(email))
    WHERE NOT is_deleted;

-- Hash: the front desk finds a reader by phone, only with "=".
CREATE INDEX ix_readers_phone_hash ON readers USING HASH (phone);

-- GIN, full-text: search over book titles in fn_search_books.
CREATE INDEX ix_books_title_fts ON books USING GIN (to_tsvector('simple', title));

-- B-tree on foreign keys used in joins (PostgreSQL does not index foreign keys by itself).
CREATE INDEX ix_books_publisher_id ON books (publisher_id);
CREATE INDEX ix_books_genre_id ON books (genre_id);
CREATE INDEX ix_book_authors_author_id ON book_authors (author_id);
CREATE INDEX ix_book_copies_book_id ON book_copies (book_id);
CREATE INDEX ix_loans_copy_id ON loans (copy_id);
CREATE INDEX ix_reader_memberships_reader_end ON reader_memberships (reader_id, end_date);
CREATE INDEX ix_reservations_reader_book ON reservations (reader_id, book_id) WHERE status = 'active';
CREATE INDEX ix_service_orders_reader_id ON service_orders (reader_id);
CREATE INDEX ix_payments_reader_id ON payments (reader_id);
