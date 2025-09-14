SELECT dbms_metadata.get_dependent_ddl('ENUM','table_all','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_dependent_ddl('ENUM','table_all');
