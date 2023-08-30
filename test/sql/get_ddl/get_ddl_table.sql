SELECT dbms_metadata.get_ddl('TABLE','table_all','gdmmm');

SELECT dbms_metadata.get_ddl('TABLE','table_all_child','gdmmm');

SELECT dbms_metadata.get_ddl('TABLE','sales','gdmmm');

SELECT dbms_metadata.get_ddl('TABLE','Sample unlogged table','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('TABLE','table_all');

SELECT dbms_metadata.get_ddl('TABLE','table_all_child');

SELECT dbms_metadata.get_ddl('TABLE','sales');

SELECT dbms_metadata.get_ddl('TABLE','Sample unlogged table');
