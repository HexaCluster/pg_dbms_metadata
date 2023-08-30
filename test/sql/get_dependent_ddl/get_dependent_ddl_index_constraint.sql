SELECT dbms_metadata.get_dependent_ddl('INDEX','table_all','gdmmm');

SELECT dbms_metadata.get_dependent_ddl('INDEX','Sample unlogged table','gdmmm');

SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','table_all','gdmmm');

SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','table_all_child','gdmmm');

SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','Sample unlogged table','gdmmm');

SELECT dbms_metadata.get_dependent_ddl('REF_CONSTRAINT','table_all_child','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_dependent_ddl('INDEX','table_all');

SELECT dbms_metadata.get_dependent_ddl('INDEX','Sample unlogged table');

SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','table_all');

SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','table_all_child');

SELECT dbms_metadata.get_dependent_ddl('CONSTRAINT','Sample unlogged table');
