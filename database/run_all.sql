-- Builds the whole database from scratch. Run from any folder:
--   psql -h localhost -U postgres -d library_lab -f database/run_all.sql
\set ON_ERROR_STOP on

\ir 0_reset.sql
\ir 1_tables_create.sql
\ir 2_functions_create.sql
\ir 3_views_create.sql
\ir 4_procedures_create.sql
\ir 5_triggers_create.sql
\ir 6_indexes_create.sql
\ir 7_seed_data.sql
