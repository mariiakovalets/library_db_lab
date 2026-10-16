-- Library management system with additional services: tables.
-- Naming: snake_case, plural table names, surrogate primary key "id",
-- foreign keys "<entity>_id", natural keys kept as UNIQUE (alternate keys).

--  Staff 

CREATE TABLE roles (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE staff_users (
    id         SERIAL PRIMARY KEY,
    role_id    INTEGER      NOT NULL REFERENCES roles (id),
    full_name  VARCHAR(255) NOT NULL,
    email      VARCHAR(255) NOT NULL UNIQUE,
    is_deleted BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    updated_by INTEGER REFERENCES staff_users (id)
);

--  Catalog: a book as an edition 

CREATE TABLE publishers (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(255) NOT NULL UNIQUE,
    address      VARCHAR(255),
    founded_year INTEGER CHECK (founded_year BETWEEN 1450 AND 2100)
);

CREATE TABLE authors (
    id         SERIAL PRIMARY KEY,
    full_name  VARCHAR(255) NOT NULL,
    birth_year INTEGER CHECK (birth_year BETWEEN 1000 AND 2100),
    is_deleted BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    updated_by INTEGER REFERENCES staff_users (id)
);

CREATE TABLE genres (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE books (
    id           SERIAL PRIMARY KEY,
    isbn         VARCHAR(17)  NOT NULL,  -- unique among non-deleted books, see 6_indexes_create.sql
    title        VARCHAR(255) NOT NULL,
    publisher_id INTEGER      NOT NULL REFERENCES publishers (id),
    genre_id     INTEGER      NOT NULL REFERENCES genres (id),
    publish_year INTEGER CHECK (publish_year BETWEEN 1450 AND 2100),
    pages_count  INTEGER CHECK (pages_count > 0),
    is_deleted   BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ,
    updated_by   INTEGER REFERENCES staff_users (id)
);

CREATE TABLE book_authors (
    book_id   INTEGER NOT NULL REFERENCES books (id),
    author_id INTEGER NOT NULL REFERENCES authors (id),
    PRIMARY KEY (book_id, author_id)
);

--  Copies: physical items on the shelf 

CREATE TABLE book_copies (
    id               SERIAL PRIMARY KEY,
    book_id          INTEGER     NOT NULL REFERENCES books (id),
    inventory_number VARCHAR(20) NOT NULL UNIQUE,
    status           VARCHAR(20) NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'loaned', 'written_off')),
    acquired_at      DATE        NOT NULL DEFAULT current_date,
    is_deleted       BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ,
    updated_by       INTEGER REFERENCES staff_users (id)
);

--  Readers and memberships 

CREATE TABLE readers (
    id                  SERIAL PRIMARY KEY,
    library_card_number VARCHAR(20)  NOT NULL UNIQUE,
    full_name           VARCHAR(255) NOT NULL,
    email               VARCHAR(255),  -- unique among non-deleted readers, see 6_indexes_create.sql
    phone               VARCHAR(20),
    birth_date          DATE,
    is_deleted          BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ,
    updated_by          INTEGER REFERENCES staff_users (id)
);

CREATE TABLE membership_plans (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(50)    NOT NULL UNIQUE,
    price         NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    duration_days INTEGER        NOT NULL CHECK (duration_days > 0),
    max_books     INTEGER        NOT NULL CHECK (max_books > 0),
    loan_days     INTEGER        NOT NULL CHECK (loan_days > 0)
);

CREATE TABLE reader_memberships (
    id         SERIAL PRIMARY KEY,
    reader_id  INTEGER     NOT NULL REFERENCES readers (id),
    plan_id    INTEGER     NOT NULL REFERENCES membership_plans (id),
    start_date DATE        NOT NULL,
    end_date   DATE        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_date > start_date)
);

--  Circulation 

CREATE TABLE loans (
    id          SERIAL PRIMARY KEY,
    copy_id     INTEGER     NOT NULL REFERENCES book_copies (id),
    reader_id   INTEGER     NOT NULL REFERENCES readers (id),
    issued_by   INTEGER     NOT NULL REFERENCES staff_users (id),
    issued_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    due_date    DATE        NOT NULL,
    returned_at TIMESTAMPTZ,  -- NULL while the book is with the reader
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ,
    updated_by  INTEGER REFERENCES staff_users (id),
    CHECK (returned_at IS NULL OR returned_at >= issued_at)
);

CREATE TABLE reservations (
    id          SERIAL PRIMARY KEY,
    book_id     INTEGER     NOT NULL REFERENCES books (id),
    reader_id   INTEGER     NOT NULL REFERENCES readers (id),
    reserved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'fulfilled', 'cancelled', 'expired')),
    CHECK (expires_at > reserved_at)
);

CREATE TABLE fines (
    id         SERIAL PRIMARY KEY,
    loan_id    INTEGER        NOT NULL UNIQUE REFERENCES loans (id),  -- 1:1 with loans
    amount     NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    reason     VARCHAR(255)   NOT NULL,
    status     VARCHAR(20)    NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid')),
    created_at TIMESTAMPTZ    NOT NULL DEFAULT now()
);

--  Additional services 

CREATE TABLE services (
    id                SERIAL PRIMARY KEY,
    name              VARCHAR(100)   NOT NULL UNIQUE,
    description       VARCHAR(500),
    price             NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    unit              VARCHAR(20)    NOT NULL CHECK (unit IN ('page', 'hour', 'request')),
    requires_schedule BOOLEAN        NOT NULL DEFAULT FALSE,
    is_deleted        BOOLEAN        NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ,
    updated_by        INTEGER REFERENCES staff_users (id)
);

CREATE TABLE service_orders (
    id           SERIAL PRIMARY KEY,
    reader_id    INTEGER        NOT NULL REFERENCES readers (id),
    service_id   INTEGER        NOT NULL REFERENCES services (id),
    quantity     INTEGER        NOT NULL DEFAULT 1 CHECK (quantity > 0),
    total_price  NUMERIC(10, 2) NOT NULL CHECK (total_price >= 0),
    scheduled_at TIMESTAMPTZ,  -- date and time for services that need booking
    status       VARCHAR(20)    NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'completed', 'cancelled')),
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ,
    updated_by   INTEGER REFERENCES staff_users (id)
);

--  Payments 

CREATE TABLE payments (
    id                   SERIAL PRIMARY KEY,
    reader_id            INTEGER        NOT NULL REFERENCES readers (id),
    amount               NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    method               VARCHAR(10)    NOT NULL CHECK (method IN ('cash', 'card')),
    paid_at              TIMESTAMPTZ    NOT NULL DEFAULT now(),
    received_by          INTEGER        NOT NULL REFERENCES staff_users (id),
    fine_id              INTEGER REFERENCES fines (id),
    reader_membership_id INTEGER REFERENCES reader_memberships (id),
    service_order_id     INTEGER REFERENCES service_orders (id),
    -- a payment covers exactly one thing: a fine, a membership or a service order
    CHECK (num_nonnulls(fine_id, reader_membership_id, service_order_id) = 1)
);
