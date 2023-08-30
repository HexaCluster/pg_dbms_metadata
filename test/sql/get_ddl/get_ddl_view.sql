SELECT dbms_metadata.get_ddl('VIEW','gg_d','gdmmm');

SELECT dbms_metadata.get_ddl('VIEW','Global fines','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('VIEW','gg_d');

SELECT dbms_metadata.get_ddl('VIEW','Global fines');
