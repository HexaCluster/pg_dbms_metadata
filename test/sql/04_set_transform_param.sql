SELECT dbms_metadata.get_ddl('TABLE','table_all','gdmmm');
CALL dbms_metadata.set_transform_param('SQLTERMINATOR',true);
SELECT dbms_metadata.get_ddl('TABLE','table_all','gdmmm');
CALL dbms_metadata.set_transform_param('DEFAULT');
SELECT dbms_metadata.get_ddl('TABLE','table_all','gdmmm');