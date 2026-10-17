-- Data dictionary (V31-V33): every table and every column of the application describes itself, so DBeaver shows
-- what each one means. Fails, naming what is missing, if someone adds a table or column without a description.
\ir _asserts.sql

SELECT pg_temp.assert_true(missing IS NULL, 'every table has a description' || coalesce(' (falta: ' || missing || ')', ''))
FROM (SELECT string_agg(c.relname, ', ' ORDER BY c.relname) AS missing
      FROM pg_class c
      WHERE c.relkind = 'r' AND c.relnamespace = 'public'::regnamespace AND c.relname <> 'flyway_schema_history'
        AND obj_description(c.oid, 'pg_class') IS NULL) AS t;

SELECT pg_temp.assert_true(missing IS NULL, 'every column has a description' || coalesce(' (falta: ' || missing || ')', ''))
FROM (SELECT string_agg(c.relname || '.' || a.attname, ', ' ORDER BY c.relname, a.attnum) AS missing
      FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
      WHERE c.relkind = 'r' AND c.relnamespace = 'public'::regnamespace AND c.relname <> 'flyway_schema_history'
        AND col_description(c.oid, a.attnum) IS NULL) AS t;

SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM pg_description d JOIN pg_class c ON c.oid = d.objoid
                WHERE c.relnamespace = 'public'::regnamespace AND length(btrim(d.description)) < 5),
    'no description is an empty placeholder');
