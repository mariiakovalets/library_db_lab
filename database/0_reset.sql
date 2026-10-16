-- Recreates an empty public schema in the library_lab database.
-- Run only against library_lab: it drops every object in the schema.
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
