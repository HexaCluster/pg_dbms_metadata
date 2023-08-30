SELECT dbms_metadata.get_dependent_ddl('SEQUENCE','table_all','gdmmm');

SELECT dbms_metadata.get_dependent_ddl('SEQUENCE','Sample unlogged table','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_dependent_ddl('SEQUENCE','table_all');

SELECT dbms_metadata.get_dependent_ddl('SEQUENCE','Sample unlogged table');
