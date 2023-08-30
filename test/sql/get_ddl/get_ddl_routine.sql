SELECT dbms_metadata.get_ddl('FUNCTION','Merge objects','gdmmm');

SELECT dbms_metadata.get_ddl('PROCEDURE','join_entity','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('FUNCTION','Merge objects');

SELECT dbms_metadata.get_ddl('PROCEDURE','join_entity');