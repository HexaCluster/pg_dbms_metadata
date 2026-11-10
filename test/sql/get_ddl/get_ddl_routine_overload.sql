RESET search_path;

-- all overloaded functions are returned, the procedure is not
SELECT dbms_metadata.get_ddl('FUNCTION','overloaded_routine','gdmmm');

-- only the procedure is returned
SELECT dbms_metadata.get_ddl('PROCEDURE','overloaded_routine','gdmmm');

-- a single overloaded function is selected by its argument list
SELECT dbms_metadata.get_ddl('FUNCTION','overloaded_routine(text, integer)','gdmmm');

SELECT dbms_metadata.get_ddl('FUNCTION','overloaded_routine(text)','gdmmm');

-- SQLTERMINATOR is applied to each overloaded function
CALL dbms_metadata.set_transform_param('SQLTERMINATOR', true);

SELECT dbms_metadata.get_ddl('FUNCTION','overloaded_routine','gdmmm');

CALL dbms_metadata.set_transform_param('SQLTERMINATOR', false);

-- tests for schema as NULL
SET search_path TO public, gdmmm;

SELECT dbms_metadata.get_ddl('FUNCTION','overloaded_routine');

SELECT dbms_metadata.get_ddl('FUNCTION','overloaded_routine(text)');
