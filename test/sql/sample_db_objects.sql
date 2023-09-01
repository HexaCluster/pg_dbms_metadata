CREATE SCHEMA gdmmm;

----
-- Table 1
----
CREATE TABLE gdmmm.table_all (
    a serial PRIMARY KEY,   -- dependent sequence test
    b int NOT NULL, -- NOT NULL test
    c varchar(20) DEFAULT 'def',    -- default value test
    d int UNIQUE
) WITH (
    autovacuum_enabled = false,            
    fillfactor = 70,                       
    toast_tuple_target = 200,              
    autovacuum_vacuum_scale_factor = 0.2,  
    autovacuum_analyze_scale_factor = 0.1  
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
    CONSTRAINT "Fk_customer" FOREIGN KEY (id) REFERENCES gdmmm.table_all (a)
);

ALTER TABLE gdmmm.table_all_child ADD CONSTRAINT child_uniq UNIQUE(id);

----
-- Partition Table
----
CREATE TABLE IF NOT EXISTS gdmmm.sales
(
    sale_id integer NOT NULL,
    "Sale date" date NOT NULL,
    amount numeric,
    CONSTRAINT sales_pkey PRIMARY KEY (sale_id, "Sale date")
) PARTITION BY RANGE ("Sale date");

CREATE TABLE gdmmm.sales_february PARTITION OF gdmmm.sales
    FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');

CREATE TABLE gdmmm.sales_january PARTITION OF gdmmm.sales
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

----
-- Unlogged Table
----
CREATE UNLOGGED TABLE gdmmm."Sample unlogged table" (
    id serial PRIMARY KEY,
    "name of customer" varchar(255),    -- quote ident test
    "Age" integer,
    "Birth_Date" DATE,
    CONSTRAINT "check" CHECK ("Birth_Date" > '1900-01-01')
);

COMMENT ON COLUMN gdmmm."Sample unlogged table"."name of customer" IS 'This is a comment for the column.';

CREATE INDEX "Gin_Index_Name" ON gdmmm."Sample unlogged table" USING spgist ("name of customer");

ALTER TABLE gdmmm."Sample unlogged table" ADD CONSTRAINT "Unique age" UNIQUE("Age"); 

----
-- View 1
----
CREATE OR REPLACE VIEW gdmmm.gg_d AS
SELECT
    table_all.a
FROM
    gdmmm.table_all;

----
-- View 2
----
CREATE OR REPLACE VIEW gdmmm."Global fines" AS
SELECT
    "Sample unlogged table"."name of customer"
FROM
    gdmmm."Sample unlogged table";

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

CREATE TRIGGER "order"
    BEFORE INSERT ON gdmmm.table_all
    FOR EACH ROW
    EXECUTE FUNCTION gdmmm.double_salary ();

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
CREATE SEQUENCE IF NOT EXISTS gdmmm."attach Line"
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
CREATE TYPE gdmmm."Address" AS (
    "City" character varying,
    loc gdmmm.location,
    pin bigint
);

----
-- Function
----
CREATE OR REPLACE FUNCTION gdmmm."Merge objects" ("First_val" text, actual_finder gdmmm."Address")
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE PARALLEL UNSAFE
    AS $BODY$
BEGIN
    RETURN "First_val" || actual_finder."City";
END
$BODY$;

----
-- Procedure
----
CREATE OR REPLACE PROCEDURE gdmmm.join_entity (INOUT var_str text, INOUT num_low bigint, INOUT var_init text, INOUT mid_finder gdmmm."Address")
LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
    num_low := mid_finder.pin;
    var_init := var_str || ', ' || mid_finder."City";
END
$BODY$;

----
-- Users and Roles
----
CREATE ROLE "Role_test";

CREATE ROLE role_test2;

CREATE USER "user";

GRANT "Role_test", role_test2 TO "user";
