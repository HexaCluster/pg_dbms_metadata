SELECT dbms_metadata.get_ddl('SEQUENCE','attach Line','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('SEQUENCE','attach Line');
