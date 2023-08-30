SELECT dbms_metadata.get_ddl('INDEX','perf_index','gdmmm');

SELECT dbms_metadata.get_ddl('CONSTRAINT','child_uniq','gdmmm');

SELECT dbms_metadata.get_ddl('REF_CONSTRAINT','fk_customer','gdmmm');

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('INDEX','perf_index');

SELECT dbms_metadata.get_ddl('CONSTRAINT','child_uniq');