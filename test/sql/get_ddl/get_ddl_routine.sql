SELECT dbms_metadata.get_ddl('FUNCTION','merge_objects','gdmmm');

SELECT dbms_metadata.get_ddl('PROCEDURE','join_entity','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('FUNCTION','merge_objects');

SELECT dbms_metadata.get_ddl('PROCEDURE','join_entity');