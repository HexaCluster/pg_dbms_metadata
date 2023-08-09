CREATE SCHEMA gdmmm;

CREATE TABLE gdmmm.table_all (
    a serial PRIMARY KEY,
    b int NOT NULL,
    c varchar(20),
    d int UNIQUE
);

COMMENT ON TABLE gdmmm.table_all IS 'This is a comment for the table.';

COMMENT ON COLUMN gdmmm.table_all.a IS 'This is a comment for the column.';

CREATE INDEX ON gdmmm.table_all (c);

CREATE TABLE gdmmm.table_all_child (
    id int,
    CONSTRAINT fk_customer FOREIGN KEY (id) REFERENCES gdmmm.table_all (a)
);

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

CREATE SEQUENCE IF NOT EXISTS gdmmm.attach_line
INCREMENT 1 START 1
MINVALUE 1
MAXVALUE 9223372036854775807
CACHE 1;

CREATE TYPE gdmmm.location AS (
    lat double precision,
    lon double precision
);

CREATE TYPE gdmmm.address AS (
    city character varying,
    loc gdmmm.location,
    pin bigint
);

CREATE OR REPLACE FUNCTION gdmmm.merge_objects (first_val text, actual_finder gdmmm.address)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE PARALLEL UNSAFE
    AS $BODY$
BEGIN
    RETURN first_val || actual_finder.city;
END
$BODY$;

CREATE OR REPLACE PROCEDURE gdmmm.join_entity (var_str text, INOUT num_low bigint, INOUT var_init text, mid_finder gdmmm.address)
LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
    num_low := mid_finder.pin;
    var_init := var_str || ', ' || mid_finder.city;
END
$BODY$;

