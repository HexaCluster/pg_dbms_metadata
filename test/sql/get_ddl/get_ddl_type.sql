SELECT dbms_metadata.get_ddl('TYPE','Address','gdmmm');

SELECT dbms_metadata.get_ddl('TYPE','location','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('TYPE','Address');

SELECT dbms_metadata.get_ddl('TYPE','location');
