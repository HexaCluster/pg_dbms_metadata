SELECT dbms_metadata.get_ddl('INDEX','perf_index','gdmmm');

SELECT dbms_metadata.get_ddl('INDEX','Gin_Index_Name','gdmmm');

SELECT dbms_metadata.get_ddl('CONSTRAINT','child_uniq','gdmmm');

SELECT dbms_metadata.get_ddl('CONSTRAINT','Unique age','gdmmm');

SELECT dbms_metadata.get_ddl('REF_CONSTRAINT','Fk_customer','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('INDEX','perf_index');

SELECT dbms_metadata.get_ddl('INDEX','Gin_Index_Name');

SELECT dbms_metadata.get_ddl('CONSTRAINT','child_uniq');

SELECT dbms_metadata.get_ddl('CONSTRAINT','Unique age');
