CREATE SCHEMA gdmmm;

----
-- Table 1
----
CREATE TABLE gdmmm.table_all (
    a serial PRIMARY KEY,
    b int NOT NULL,
    c varchar(20),
    d int UNIQUE
);

COMMENT ON TABLE gdmmm.table_all IS 'This is a comment for the table.';

COMMENT ON COLUMN gdmmm.table_all.a IS 'This is a comment for the column.';

COMMENT ON COLUMN gdmmm.table_all.b IS 'This is a comment for the column.';

CREATE INDEX perf_index ON gdmmm.table_all (c);

----
-- Table 2
----
CREATE TABLE gdmmm.table_all_child (
    id int,
    CONSTRAINT fk_customer FOREIGN KEY (id) REFERENCES gdmmm.table_all (a)
);

ALTER TABLE gdmmm.table_all_child ADD CONSTRAINT child_uniq UNIQUE(id);

----
-- Partition Table
----
CREATE TABLE IF NOT EXISTS gdmmm.sales
(
    sale_id integer NOT NULL,
    sale_date date NOT NULL,
    amount numeric,
    CONSTRAINT sales_pkey PRIMARY KEY (sale_id, sale_date)
) PARTITION BY RANGE (sale_date);

CREATE TABLE gdmmm.sales_february PARTITION OF gdmmm.sales
    FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');

CREATE TABLE gdmmm.sales_january PARTITION OF gdmmm.sales
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

----
-- Unlogged Table
----
CREATE UNLOGGED TABLE gdmmm.sample_unlogged_table (
    id serial PRIMARY KEY,
    name varchar(255),
    age integer
);

----
-- Trigger 1
----
CREATE OR REPLACE FUNCTION gdmmm.double_salary ()
    RETURNS TRIGGER
    AS $$
BEGIN
    NEW.b = NEW.b * 2;
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trigger_double_salary
    BEFORE INSERT ON gdmmm.table_all
    FOR EACH ROW
    EXECUTE FUNCTION gdmmm.double_salary ();

CREATE OR REPLACE VIEW gdmmm.gg_d AS
SELECT
    table_all.a
FROM
    gdmmm.table_all;

----
-- Trigger 2
----
CREATE OR REPLACE FUNCTION gdmmm.edit_text()
RETURNS TRIGGER AS $$
BEGIN
    NEW.c = NEW.c || 'edit';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_edit_text
BEFORE INSERT ON gdmmm.table_all
FOR EACH ROW
EXECUTE FUNCTION gdmmm.edit_text();

----
-- Sequence
----
CREATE SEQUENCE IF NOT EXISTS gdmmm.attach_line
INCREMENT 1 START 1
MINVALUE 1
MAXVALUE 9223372036854775807
CACHE 1;

----
-- Type 1
----
CREATE TYPE gdmmm.location AS (
    lat double precision,
    lon double precision
);

----
-- Type 2
----
CREATE TYPE gdmmm.address AS (
    city character varying,
    loc gdmmm.location,
    pin bigint
);

----
-- Function
----
CREATE OR REPLACE FUNCTION gdmmm.merge_objects (first_val text, actual_finder gdmmm.address)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE PARALLEL UNSAFE
    AS $BODY$
BEGIN
    RETURN first_val || actual_finder.city;
END
$BODY$;

----
-- Procedure
----
CREATE OR REPLACE PROCEDURE gdmmm.join_entity (INOUT var_str text, INOUT num_low bigint, INOUT var_init text, INOUT mid_finder gdmmm.address)
LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
    num_low := mid_finder.pin;
    var_init := var_str || ', ' || mid_finder.city;
END
$BODY$;

----
-- Users and Roles
----
CREATE ROLE role_test;

CREATE ROLE role_test2;

CREATE USER user_test;

GRANT role_test, role_test2 TO user_test;
