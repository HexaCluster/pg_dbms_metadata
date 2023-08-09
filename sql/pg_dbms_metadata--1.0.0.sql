----
-- Script to create the base objects of the pg_dbms_metadata extension
----
----
-- DBMS_METADATA.GET_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_ddl (object_type text, name text, schema text)
    RETURNS text
    AS $$
DECLARE
    l_return text;
BEGIN
    CASE object_type
    WHEN 'TABLE' THEN
        l_return := dbms_metadata.get_table_ddl (schema, name);
    WHEN 'VIEW' THEN
        l_return := dbms_metadata.get_view_ddl (schema, name);
    WHEN 'SEQUENCE' THEN
        l_return := dbms_metadata.get_sequence_ddl (schema, name);
    WHEN 'PROCEDURE' THEN
        l_return := dbms_metadata.get_routine_ddl (schema, name, object_type);
    WHEN 'FUNCTION' THEN
        l_return := dbms_metadata.get_routine_ddl (schema, name, object_type);
    ELSE
        -- Need to add other object types
        RAISE EXCEPTION 'Unknown type';
    END CASE;
    RETURN l_return;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_ddl (text, text, text) IS 'Fetches DDL of database objects. Supported object types are TABLE, VIEW, SEQUENCE, PROCEDURE, FUNCTION.';

REVOKE ALL ON FUNCTION dbms_metadata.get_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_DEPENDENT_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_dependent_ddl (object_type text, base_object_name text, base_object_schema text)
    RETURNS text
    AS $$
DECLARE
    l_return text;
BEGIN
    CASE object_type
    WHEN 'SEQUENCE' THEN
        -- This is not there in oracle
        l_return := dbms_metadata.get_sequence_ddl_of_table (base_object_schema, base_object_name);
    WHEN 'CONSTRAINT' THEN
        l_return := dbms_metadata.get_constraints_ddl_of_table (base_object_schema, base_object_name);
    WHEN 'INDEX' THEN
        -- This is not there in oracle
        l_return := dbms_metadata.get_indexes_ddl_of_table (base_object_schema, base_object_name);
    ELSE
        -- Need to add other object types
        RAISE EXCEPTION 'Unknown type';
    END CASE;
    RETURN l_return;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_dependent_ddl (text, text, text) IS 'Fetches DDL of dependent objects on provided base object. Supported dependent object types are SEQUENCE, CONSTRAINT, INDEX.';

REVOKE ALL ON FUNCTION dbms_metadata.get_dependent_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_TABLE_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_table_ddl (p_schema text, p_table text)
    RETURNS text
    AS $$
DECLARE
    l_oid oid;
    l_table_def text;
    l_tab_comments text;
    l_col_rec text;
    l_col_comments text;
    l_return text;
BEGIN
    -- Getting the OID of the table
    -- The following OID will be used to get the definition from sequences
    EXECUTE 'SELECT ''' || p_schema || '.' || p_table || '''::regclass::oid' INTO l_oid;
    -- Following SQL would get -
    -- 1. The list of columns of the Table in the order of the attnum
    -- 2. Datatypes set to the columns
    -- 3. DEFAULT values set to the columns
    -- 4. NOT NULL constraints set to the columns
    SELECT
        string_agg(a.col, ',')
    FROM (
        SELECT
            concat(a.attname || ' ' || format_type(a.atttypid, a.atttypmod), ' ', (
                    SELECT
                        concat('DEFAULT ', substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid)
                                FOR 128))
                    FROM pg_catalog.pg_attrdef d
                    WHERE
                        d.adrelid = a.attrelid
                        AND d.adnum = a.attnum
                        AND a.atthasdef), CASE WHEN a.attnotnull THEN
                        ' NOT NULL'
                    END) AS "col"
        FROM
            pg_attribute a
            JOIN pg_class b ON a.attrelid = b.oid
            JOIN pg_namespace c ON b.relnamespace = c.oid
        WHERE
            a.attname NOT IN ('tableoid', 'cmax', 'xmax', 'cmin', 'xmin', 'ctid')
            AND attisdropped IS FALSE
            AND b.relname = p_table
            AND c.nspname = p_schema
        ORDER BY
            attnum) a INTO l_table_def;
    -- Get comments on the Table if any
    SELECT
        'COMMENT ON TABLE ' || p_schema || '.' || p_table || ' IS TEXTVALUE0;' INTO l_tab_comments;
    -- Get comments on the columns of the Table if any
    FOR l_col_rec IN (
        SELECT
            'COMMENT ON COLUMN ' || p_schema || '.' || p_table || '.' || attname || ' IS TEXTVALUE1;'
        FROM
            pg_catalog.pg_attribute
        WHERE
            attname NOT IN ('tableoid', 'cmax', 'xmax', 'cmin', 'xmin', 'ctid')
            AND attisdropped IS FALSE
            AND attrelid = l_oid
            AND pg_catalog.col_description(l_oid, attnum) IS NOT NULL)
        LOOP
            IF l_col_comments IS NULL THEN
                l_col_comments := concat(l_col_rec, chr(10));
            ELSE
                l_col_comments := concat(l_col_comments, l_col_rec, chr(10));
            END IF;
        END LOOP;
    -- Add Table DDL with its columns and their datatypes to the Output
    l_return := concat(l_return, '-- Table definition' || chr(10) || 'CREATE TABLE ' || p_schema || '.' || p_table || ' (' || l_table_def || ') TABLESPACE :"TABLESPACE_DATA";');
    -- Append Comments on Table to the Output
    l_return := concat(l_return, (chr(10) || chr(10) || '-- Table comments' || chr(10) || l_tab_comments));
    -- Append Comments on Columns of Table to the Output
    l_return := concat(l_return, (chr(10) || chr(10) || '-- Column comments' || chr(10) || l_col_comments));
    -- Return the final Table DDL prepared with Comments on Table and Columns
    RETURN l_return;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_table_ddl (text, text) IS 'This function fetches a basic table DDL without constraints and indexes. DDL will include list of columns of the table, along with datatypes, DEFAULT values and NOT NULL constraints, in the order of the attnum. DDL will also include comments on table and columns if any.';

REVOKE ALL ON FUNCTION dbms_metadata.get_table_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_SEQUENCE_DDL_OF_TABLE
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_sequence_ddl_of_table (p_schema text, p_table text)
    RETURNS text
    AS $$
DECLARE
    l_seq_rec text;
    l_sequences text;
    l_return text;
BEGIN
    -- Get the CREATE SEQUENCE statements
    --     for all the sequences belonging to the table
    FOR l_seq_rec IN (
        SELECT
            'CREATE SEQUENCE ' || p_schema || '.' || sequencename || ' START WITH ' || start_value || ' INCREMENT BY ' || increment_by || ' MINVALUE ' || min_value || ' MAXVALUE ' || max_value || ' CACHE ' || cache_size || ' ' || CASE WHEN CYCLE IS TRUE THEN
                'CYCLE'
            ELSE
                'NO CYCLE'
            END || ';'
        FROM
            pg_sequences
        WHERE
            schemaname = p_schema
            AND sequencename IN (
                SELECT
                    s.relname AS sequence
                FROM
                    pg_class s
                    JOIN pg_namespace sn ON sn.oid = s.relnamespace
                    JOIN pg_depend d ON d.refobjid = s.oid
                        AND d.refclassid = 'pg_class'::regclass
                    JOIN pg_attrdef ad ON ad.oid = d.objid
                        AND d.classid = 'pg_attrdef'::regclass
                    JOIN pg_attribute col ON col.attrelid = ad.adrelid
                        AND col.attnum = ad.adnum
                    JOIN pg_class tbl ON tbl.oid = ad.adrelid
                    JOIN pg_namespace ts ON ts.oid = tbl.relnamespace
                WHERE
                    s.relkind = 'S'
                    AND d.deptype IN ('a', 'n')
                    AND ts.nspname = p_schema
                    AND tbl.relname = p_table))
            LOOP
                IF l_sequences IS NULL THEN
                    l_sequences := concat(l_seq_rec, chr(10));
                ELSE
                    l_sequences := concat(l_sequences, l_seq_rec, chr(10));
                END IF;
            END LOOP;
    -- Return the CREATE SEQUENCE statements to the DDL Output
    l_return := concat(l_sequences || chr(10));
    -- Return the final Sequences DDL prepared
    RETURN l_return;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_sequence_ddl_of_table (text, text) IS 'This function fetches DDL of all dependent sequences on provided table';

REVOKE ALL ON FUNCTION dbms_metadata.get_sequence_ddl_of_table FROM PUBLIC;

----
-- DBMS_METADATA.GET_CONSTRAINTS_DDL_OF_TABLE
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_constraints_ddl_of_table (p_schema text, p_table text)
    RETURNS text
    AS $$
DECLARE
    l_oid oid;
    l_const_rec record;
    l_constraints text;
    l_return text;
    l_fkey_rec text;
    l_fkey text;
BEGIN
    -- Getting the OID of the table
    EXECUTE 'SELECT ''' || p_schema || '.' || p_table || '''::regclass::oid' INTO l_oid;
    -- Get Constraints Definitions
    FOR l_const_rec IN (
        SELECT
            c2.relname,
            i.indisprimary,
            i.indisunique,
            i.indisclustered,
            i.indisvalid,
            pg_catalog.pg_get_indexdef(i.indexrelid, 0, TRUE),
            pg_catalog.pg_get_constraintdef(con.oid, TRUE),
            contype,
            condeferrable,
            condeferred,
            c2.reltablespace,
            conname
        FROM
            pg_catalog.pg_class c,
            pg_catalog.pg_class c2,
            pg_catalog.pg_index i
        LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid
                AND conindid = i.indexrelid
                AND contype IN ('p', 'u', 'x', 'f'))
    WHERE
        c.oid = l_oid
        AND c.oid = i.indrelid
        AND i.indexrelid = c2.oid
    ORDER BY
        i.indisprimary DESC,
        i.indisunique DESC,
        c2.relname)
        LOOP
            IF l_const_rec.contype IS NOT NULL THEN
                l_constraints := concat(l_constraints, format('ALTER TABLE %I.%I ADD CONSTRAINT %I ', p_schema, p_table, l_const_rec.conname), l_const_rec.pg_get_constraintdef, ' USING INDEX TABLESPACE :"TABLESPACE_INDEX";', chr(10));
            END IF;
        END LOOP;
    FOR l_fkey_rec IN (
        SELECT
            'ALTER TABLE ' || nspname || '.' || relname || ' ADD CONSTRAINT ' || conname || ' ' || pg_get_constraintdef(pg_constraint.oid) || ' USING INDEX TABLESPACE :"TABLESPACE_INDEX";'
        FROM
            pg_constraint
            INNER JOIN pg_class ON conrelid = pg_class.oid
            INNER JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
        WHERE
            contype = 'f'
            AND nspname = p_schema
            AND relname = p_table)
        LOOP
            IF l_fkey IS NULL THEN
                l_fkey := concat(l_fkey_rec, chr(10));
            ELSE
                l_fkey := concat(l_fkey, l_fkey_rec, chr(10));
            END IF;
        END LOOP;
    -- Start Appending all the DDLs created until now and return the final DDL output
    -- Append Constraints of Table to the Output
    l_return := concat(l_return, ('-- Constraints' || chr(10) || l_constraints));
    -- Append Foreign Key Constraints to the Output
    l_return := concat(l_return, (chr(10) || chr(10) || '-- Foreign Key Constraints' || chr(10) || l_fkey));
    -- Return the final DDL prepared
    RETURN l_return;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_constraints_ddl_of_table (text, text) IS 'This function fetches DDL of all constraints of provided table';

REVOKE ALL ON FUNCTION dbms_metadata.get_constraints_ddl_of_table FROM PUBLIC;

----
-- DBMS_METADATA.GET_INDEXES_DDL_OF_TABLE
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_indexes_ddl_of_table (p_schema text, p_table text)
    RETURNS text
    AS $$
DECLARE
    l_oid oid;
    l_const_rec record;
    l_indexes text;
    l_return text;
BEGIN
    -- Getting the OID of the table
    EXECUTE 'SELECT ''' || p_schema || '.' || p_table || '''::regclass::oid' INTO l_oid;
    -- Get Index Definitions
    FOR l_const_rec IN (
        SELECT
            c2.relname,
            i.indisprimary,
            i.indisunique,
            i.indisclustered,
            i.indisvalid,
            pg_catalog.pg_get_indexdef(i.indexrelid, 0, TRUE),
            pg_catalog.pg_get_constraintdef(con.oid, TRUE),
            contype,
            condeferrable,
            condeferred,
            c2.reltablespace,
            conname
        FROM
            pg_catalog.pg_class c,
            pg_catalog.pg_class c2,
            pg_catalog.pg_index i
        LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid
                AND conindid = i.indexrelid
                AND contype IN ('p', 'u', 'x', 'f'))
    WHERE
        c.oid = l_oid
        AND c.oid = i.indrelid
        AND i.indexrelid = c2.oid
    ORDER BY
        i.indisprimary DESC,
        i.indisunique DESC,
        c2.relname)
        LOOP
            IF l_const_rec.contype IS NULL THEN
                l_indexes := concat(l_indexes, l_const_rec.pg_get_indexdef, ' TABLESPACE :"TABLESPACE_INDEX";', chr(10));
            END IF;
        END LOOP;
    l_return := l_indexes;
    -- Return the final DDL prepared
    RETURN l_return;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_indexes_ddl_of_table (text, text) IS 'This function fetches DDL of all indexes of provided table';

REVOKE ALL ON FUNCTION dbms_metadata.get_indexes_ddl_of_table FROM PUBLIC;

----
-- DBMS_METADATA.GET_VIEW_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_view_ddl (view_schema text, view_name text)
    RETURNS text
    AS $$
DECLARE
    l_return text;
BEGIN
    SELECT
        'CREATE VIEW ' || quote_ident(view_schema) || '.' || quote_ident(view_name) || ' AS ' || pg_get_viewdef(quote_ident(view_schema) || '.' || quote_ident(view_name)) INTO l_return;
    RETURN l_return;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_view_ddl (text, text) IS 'This function fetches DDL of a view';

REVOKE ALL ON FUNCTION dbms_metadata.get_view_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_SEQUENCE_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_sequence_ddl (p_schema text, p_sequence text)
    RETURNS text
    AS $$
DECLARE
    l_return text;
BEGIN
    SELECT
        'CREATE SEQUENCE ' || p_schema || '.' || sequencename || ' START WITH ' || start_value || ' INCREMENT BY ' || increment_by || ' MINVALUE ' || min_value || ' MAXVALUE ' || max_value || ' CACHE ' || cache_size || ' ' || CASE WHEN CYCLE IS TRUE THEN
            'CYCLE'
        ELSE
            'NO CYCLE'
        END || ';' INTO l_return
    FROM
        pg_sequences
    WHERE
        schemaname = p_schema
        AND sequencename = p_sequence;
    RETURN l_return;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_sequence_ddl (text, text) IS 'This function fetches DDL of a sequence';

REVOKE ALL ON FUNCTION dbms_metadata.get_sequence_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_ROUTINE_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_routine_ddl (schema_name text, routine_name text, routine_type text DEFAULT 'procedure')
    RETURNS text
    AS $$
DECLARE
    routine_code text;
BEGIN
    CASE WHEN routine_type = 'PROCEDURE' THEN
        routine_type = 'p';
    WHEN routine_type = 'FUNCTION' THEN
        routine_type = 'f';
    END CASE;
    SELECT
        pg_get_functiondef(p.oid) INTO routine_code
    FROM
        pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE
        n.nspname = schema_name
        AND p.proname = routine_name
        AND p.prokind = routine_type; RETURN routine_code;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_routine_ddl (text, text, text) IS 'This function fetches DDL of a procedure/function';

REVOKE ALL ON FUNCTION dbms_metadata.get_routine_ddl FROM PUBLIC;

