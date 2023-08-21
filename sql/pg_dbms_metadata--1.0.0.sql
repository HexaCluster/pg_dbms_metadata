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
    WHEN 'TRIGGER' THEN
        l_return := dbms_metadata.get_trigger_ddl (schema, name);
    WHEN 'INDEX' THEN
        l_return := dbms_metadata.get_index_ddl (schema, name);
    WHEN 'CONSTRAINT' THEN
        l_return := dbms_metadata.get_constraint_ddl (schema, name);
    WHEN 'REF_CONSTRAINT' THEN
        l_return := dbms_metadata.get_ref_constraint_ddl (schema, name);
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
    WHEN 'TRIGGER' THEN
        l_return := dbms_metadata.get_triggers_ddl_of_table (base_object_schema, base_object_name);
    WHEN 'CONSTRAINT' THEN
        l_return := dbms_metadata.get_constraints_ddl_of_table (base_object_schema, base_object_name);
    WHEN 'REF_CONSTRAINT' THEN
        l_return := dbms_metadata.get_ref_constraints_ddl_of_table (base_object_schema, base_object_name);
    WHEN 'INDEX' THEN
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
-- DBMS_METADATA.SET_TRANSFORM_PARAM
----
CREATE OR REPLACE PROCEDURE dbms_metadata.set_transform_param(name text, value text)
    AS $$
DECLARE
    l_allowed_names text[] := ARRAY[];
BEGIN
    IF NOT name = ANY(l_allowed_names) THEN
        RAISE EXCEPTION 'Name:% is not supported for value as text', name;
        RETURN;
    END IF;
    PERFORM set_config('DBMS_METADATA.' || name, value, false);
END;
$$ 
LANGUAGE plpgsql;

COMMENT ON PROCEDURE dbms_metadata.set_transform_param (text, text) IS 'Used to customize DDL through configuring session-level transform params.';

REVOKE ALL ON PROCEDURE dbms_metadata.set_transform_param FROM PUBLIC;

CREATE OR REPLACE PROCEDURE dbms_metadata.set_transform_param(name text, value boolean)
    AS $$
DECLARE
    l_allowed_names text[] := ARRAY['SQLTERMINATOR', 'CONSTRAINTS', 'REF_CONSTRAINTS'];
BEGIN
    IF NOT name = ANY(l_allowed_names) THEN
        RAISE EXCEPTION 'Name:% is not supported for value as boolean', name;
        RETURN;
    END IF;
    PERFORM set_config('DBMS_METADATA.' || name, value::text, false);
END;
$$ 
LANGUAGE plpgsql;

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
    l_partitioning_type text;
    l_partitioned_columns text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

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

    -- Get partitioning info of table
    SELECT
        CASE
            WHEN pt.partstrat = 'r' THEN 'RANGE'
            WHEN pt.partstrat = 'l' THEN 'LIST'
            WHEN pt.partstrat = 'h' THEN 'HASH'
            ELSE null
        END AS partitioning_type,
        string_agg(a.attname, ', ') AS partitioned_columns
    INTO l_partitioning_type, l_partitioned_columns
    FROM
        pg_class c
    LEFT JOIN pg_partitioned_table pt ON c.oid = pt.partrelid
    LEFT JOIN pg_attribute a ON c.oid = a.attrelid
    WHERE
        c.relnamespace = p_schema::regnamespace
        AND c.relname = p_table
        AND a.attnum = ANY(pt.partattrs)
        AND a.attnum > 0
    GROUP BY c.relname, pt.partstrat;

    -- Get comments on the Table if any
    SELECT
        'COMMENT ON TABLE ' || p_schema || '.' || p_table || ' IS '''|| obj_description(l_oid) || '''' || CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END INTO l_tab_comments
    FROM pg_class
    WHERE relkind = 'r';
    -- Get comments on the columns of the Table if any
    FOR l_col_rec IN (
        SELECT
            'COMMENT ON COLUMN ' || p_schema || '.' || p_table || '.' || attname || ' IS '''|| pg_catalog.col_description(l_oid, attnum) || '''' || CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END
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
    l_return := concat(l_return, '-- Table definition' || chr(10) || 'CREATE TABLE ' || p_schema || '.' || p_table || ' (' || l_table_def || ') TABLESPACE :"TABLESPACE_DATA"');
    
    -- Add partitioning if any
    IF l_partitioning_type IS NOT NULL THEN
        l_return := concat(l_return, ' PARTITION BY ' || l_partitioning_type || '(' || l_partitioned_columns || ')');
    END IF;

    IF l_sqlterminator THEN
        -- Add semi-colon at end
        l_return := concat(l_return, ';');
    END IF;

    -- Append Comments on Table to the Output
    l_return := concat(l_return, (chr(10) || chr(10) || '-- Table comments' || chr(10) || l_tab_comments));
    -- Append Comments on Columns of Table to the Output
    l_return := concat(l_return, (chr(10) || chr(10) || '-- Column comments' || chr(10) || l_col_comments));

    -- Return the final Table DDL prepared with Comments on Table and Columns
    RETURN l_return;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '%',SQLERRM;
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
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    -- Get the CREATE SEQUENCE statements
    --     for all the sequences belonging to the table
    FOR l_seq_rec IN (
        SELECT
            'CREATE SEQUENCE ' || p_schema || '.' || sequencename || ' START WITH ' || start_value || ' INCREMENT BY ' || increment_by || ' MINVALUE ' || min_value || ' MAXVALUE ' || max_value || ' CACHE ' || cache_size || ' ' || CASE WHEN CYCLE IS TRUE THEN
                'CYCLE'
            ELSE
                'NO CYCLE'
            END || CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END
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
    
    IF l_sequences IS NULL THEN
        RAISE EXCEPTION 'specified object of type SEQUENCE not found';
    END IF;
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
CREATE OR REPLACE FUNCTION dbms_metadata.get_constraints_ddl_of_table (
    p_schema text, 
    p_table text
) RETURNS text
    AS $$
DECLARE
    l_oid oid;
    l_const_rec record;
    l_constraints text;
    l_return text;
    l_fkey_rec text;
    l_fkey text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

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
                l_constraints := concat(l_constraints, format('ALTER TABLE %I.%I ADD CONSTRAINT %I ', p_schema, p_table, l_const_rec.conname), l_const_rec.pg_get_constraintdef, ' USING INDEX TABLESPACE :"TABLESPACE_INDEX"', CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END, chr(10));
            END IF;
        END LOOP;

    -- Append Constraints of Table to the Output
    l_return := concat(l_return, ('-- Constraints' || chr(10) || l_constraints));

    -- Return the final DDL prepared
    RETURN l_return;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '%',SQLERRM;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_constraints_ddl_of_table (text, text) IS 'This function fetches DDL of all constraints of provided table';

REVOKE ALL ON FUNCTION dbms_metadata.get_constraints_ddl_of_table FROM PUBLIC;

----
-- DBMS_METADATA.GET_REF_CONSTRAINTS_DDL_OF_TABLE
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_ref_constraints_ddl_of_table (
    p_schema text, 
    p_table text
) RETURNS text
    AS $$
DECLARE
    l_oid oid;
    l_const_rec record;
    l_return text;
    l_fkey_rec text;
    l_fkey text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    -- Getting the OID of the table
    EXECUTE 'SELECT ''' || p_schema || '.' || p_table || '''::regclass::oid' INTO l_oid;
    
    FOR l_fkey_rec IN (
        SELECT
            'ALTER TABLE ' || nspname || '.' || relname || ' ADD CONSTRAINT ' || conname || ' ' || pg_get_constraintdef(pg_constraint.oid) || ' USING INDEX TABLESPACE :"TABLESPACE_INDEX"' || CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END
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
    
    -- Append Foreign Key Constraints to the Output
    l_return := concat(l_return, (chr(10) || chr(10) || '-- Foreign Key Constraints' || chr(10) || l_fkey));

    -- Return the final DDL prepared
    RETURN l_return;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '%',SQLERRM;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_ref_constraints_ddl_of_table (text, text) IS 'This function fetches DDL of all constraints of provided table';

REVOKE ALL ON FUNCTION dbms_metadata.get_ref_constraints_ddl_of_table FROM PUBLIC;

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
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

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
                l_indexes := concat(l_indexes, l_const_rec.pg_get_indexdef, ' TABLESPACE :"TABLESPACE_INDEX"', CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END, chr(10));
            END IF;
        END LOOP;
    
    IF l_indexes IS NULL THEN
        RAISE EXCEPTION 'specified object of type INDEX not found';
    END IF;
    l_return := l_indexes;
    -- Return the final DDL prepared
    RETURN l_return;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '%',SQLERRM;
END;
$$
LANGUAGE PLPGSQL;

COMMENT ON FUNCTION dbms_metadata.get_indexes_ddl_of_table (text, text) IS 'This function fetches DDL of all indexes of provided table';

REVOKE ALL ON FUNCTION dbms_metadata.get_indexes_ddl_of_table FROM PUBLIC;

----
-- DBMS_METADATA.GET_TRIGGERS_DDL_OF_TABLE
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_triggers_ddl_of_table(schema_name text, table_name text)
RETURNS text AS
$$
DECLARE
    trigger_def text;
    l_return text := '';
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    FOR trigger_def IN
        SELECT pg_get_triggerdef(t.oid)
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = schema_name
          AND c.relname = table_name
          AND t.tgisinternal = FALSE -- Exclude system triggers
    LOOP
        l_return := l_return || trigger_def || CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END || E'\n\n';
    END LOOP;
    IF l_return = '' THEN
        RAISE EXCEPTION 'specified object of type TRIGGER not found';
    END IF;
    RETURN l_return;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_triggers_ddl_of_table (text, text) IS 'This function fetches DDL of all triggers of provided table';

REVOKE ALL ON FUNCTION dbms_metadata.get_triggers_ddl_of_table FROM PUBLIC;

----
-- DBMS_METADATA.GET_VIEW_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_view_ddl (view_schema text, view_name text)
    RETURNS text
    AS $$
DECLARE
    l_return text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    SELECT
        'CREATE VIEW ' || quote_ident(view_schema) || '.' || quote_ident(view_name) || ' AS ' || pg_get_viewdef(quote_ident(view_schema) || '.' || quote_ident(view_name)) INTO STRICT l_return;
    IF NOT l_sqlterminator THEN
        l_return := TRIM(TRAILING ';' FROM l_return);
    END IF;
    RETURN l_return;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
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
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    SELECT
        'CREATE SEQUENCE ' || p_schema || '.' || sequencename || ' START WITH ' || start_value || ' INCREMENT BY ' || increment_by || ' MINVALUE ' || min_value || ' MAXVALUE ' || max_value || ' CACHE ' || cache_size || ' ' || CASE WHEN CYCLE IS TRUE THEN
            'CYCLE'
        ELSE
            'NO CYCLE'
        END || CASE l_sqlterminator WHEN TRUE THEN ';' ELSE '' END INTO STRICT l_return
    FROM
        pg_sequences
    WHERE
        schemaname = p_schema
        AND sequencename = p_sequence;
    RETURN l_return;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Sequence with name % not found in schema %', p_sequence, p_schema;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
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
    routine_type_flag text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    CASE WHEN routine_type = 'PROCEDURE' THEN
        routine_type_flag = 'p';
    WHEN routine_type = 'FUNCTION' THEN
        routine_type_flag = 'f';
    END CASE;
    SELECT
        pg_get_functiondef(p.oid) INTO STRICT routine_code
    FROM
        pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE
        n.nspname = schema_name
        AND p.proname = routine_name
        AND p.prokind = routine_type_flag; 
    
    IF l_sqlterminator THEN
        routine_code := concat(routine_code, ';');
    END IF;
    RETURN routine_code;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION '% with name % not found in schema %',routine_type, routine_name, schema_name;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_routine_ddl (text, text, text) IS 'This function fetches DDL of a procedure/function';

REVOKE ALL ON FUNCTION dbms_metadata.get_routine_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_INDEX_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_index_ddl(schema_name text, index_name text)
RETURNS text AS
$$
DECLARE
    index_def text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    SELECT pg_indexes.indexdef INTO STRICT index_def
    FROM pg_indexes
    WHERE indexname = index_name
      AND schemaname = schema_name;
    
    IF l_sqlterminator THEN
        index_def := concat(index_def, ';');
    END IF;    
    RETURN index_def;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Index with name % not found in schema %',index_name, schema_name;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_index_ddl (text, text) IS 'This function fetches DDL of an index';

REVOKE ALL ON FUNCTION dbms_metadata.get_index_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_CONSTRAINT_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_constraint_ddl(schema_name text, constraint_name text)
RETURNS text AS
$$
DECLARE
    alter_statement text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    SELECT format('ALTER TABLE %I.%I ADD CONSTRAINT %I %s', schema_name, cl.relname, conname, pg_catalog.pg_get_constraintdef(con.oid, TRUE))
    INTO STRICT alter_statement
    FROM pg_constraint con
    JOIN pg_class cl ON con.conrelid = cl.oid
    WHERE conname = constraint_name
        AND contype <> 'f'
        AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = schema_name);
    
    IF l_sqlterminator THEN
        alter_statement := concat(alter_statement, ';');
    END IF; 
    RETURN alter_statement;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Constraint with name % not found in schema %',constraint_name, schema_name;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_constraint_ddl (text, text) IS 'This function fetches DDL of a constraint';

REVOKE ALL ON FUNCTION dbms_metadata.get_constraint_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_REF_CONSTRAINT_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_ref_constraint_ddl(schema_name text, constraint_name text)
RETURNS text AS
$$
DECLARE
    alter_statement text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    SELECT format('ALTER TABLE %I.%I ADD CONSTRAINT %I %s', schema_name, cl.relname, conname, pg_catalog.pg_get_constraintdef(con.oid, TRUE))
    INTO STRICT alter_statement
    FROM pg_constraint con
    JOIN pg_class cl ON con.conrelid = cl.oid
    WHERE conname = constraint_name
        AND contype = 'f'
        AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = schema_name);
    
    IF l_sqlterminator THEN
        alter_statement := concat(alter_statement, ';');
    END IF; 
    RETURN alter_statement;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Referential constraint with name % not found in schema %',constraint_name, schema_name;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_ref_constraint_ddl (text, text) IS 'This function fetches DDL of a constraint';

REVOKE ALL ON FUNCTION dbms_metadata.get_ref_constraint_ddl FROM PUBLIC;

----
-- DBMS_METADATA.GET_TRIGGER_DDL
----
CREATE OR REPLACE FUNCTION dbms_metadata.get_trigger_ddl(schema_name text, trigger_name text)
RETURNS text AS
$$
DECLARE
    trigger_def text;
    l_sqlterminator boolean;
BEGIN
    -- Getting values of transform params
    SELECT current_setting('DBMS_METADATA.SQLTERMINATOR')::boolean INTO l_sqlterminator;

    SELECT pg_get_triggerdef(t.oid)
    INTO STRICT trigger_def
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE t.tgname = trigger_name
      AND n.nspname = schema_name;

    IF l_sqlterminator THEN
        trigger_def := concat(trigger_def, ';');
    END IF; 
    RETURN trigger_def;
-- In postgres there can be duplicate trigger names defined in one schema, as long as they belong to different tables
-- So we need to check and error out if the trigger name is duplicated
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Trigger with name % not found in schema %', trigger_name, schema_name;
    WHEN TOO_MANY_ROWS THEN
        RAISE EXCEPTION 'Duplicate triggers found with name % in schema %', trigger_name, schema_name;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
END;
$$
LANGUAGE plpgsql;

COMMENT ON FUNCTION dbms_metadata.get_trigger_ddl (text, text) IS 'This function fetches DDL of a trigger';

REVOKE ALL ON FUNCTION dbms_metadata.get_trigger_ddl FROM PUBLIC;
