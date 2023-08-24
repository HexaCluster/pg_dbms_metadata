use Test::Simple tests => 14;

$ENV{LANG}='C';

$ret = `psql -d regress_dbms_metadata -f test/sql/get_ddl/get_ddl_table.sql > results/get_ddl/get_ddl_table.out 2>&1`;
ok( $? == 0, "test for retrieving table ddl");

$ret = `psql -d regress_dbms_metadata -f test/sql/get_ddl/get_ddl_view.sql > results/get_ddl/get_ddl_view.out 2>&1`;
ok( $? == 0, "test for retrieving view ddl");

$ret = `psql -d regress_dbms_metadata -f test/sql/get_ddl/get_ddl_sequence.sql > results/get_ddl/get_ddl_sequence.out 2>&1`;
ok( $? == 0, "test for retrieving sequence ddl");

$ret = `psql -d regress_dbms_metadata -f test/sql/get_ddl/get_ddl_routine.sql > results/get_ddl/get_ddl_routine.out 2>&1`;
ok( $? == 0, "test for retrieving routine ddl");

$ret = `psql -d regress_dbms_metadata -f test/sql/get_ddl/get_ddl_trigger.sql > results/get_ddl/get_ddl_trigger.out 2>&1`;
ok( $? == 0, "test for retrieving trigger ddl");

$ret = `psql -d regress_dbms_metadata -f test/sql/get_ddl/get_ddl_index_constraint.sql > results/get_ddl/get_ddl_index_constraint.out 2>&1`;
ok( $? == 0, "test for retrieving index and constraint ddl");

$ret = `psql -d regress_dbms_metadata -f test/sql/get_ddl/get_ddl_type.sql > results/get_ddl/get_ddl_type.out 2>&1`;
ok( $? == 0, "test for retrieving type ddl");

$ret = `diff results/get_ddl/get_ddl_table.out test/expected/get_ddl/get_ddl_table.out 2>&1`;
ok( $? == 0, "diff for retrieving table ddl");

$ret = `diff results/get_ddl/get_ddl_view.out test/expected/get_ddl/get_ddl_view.out 2>&1`;
ok( $? == 0, "diff for retrieving view ddl");

$ret = `diff results/get_ddl/get_ddl_sequence.out test/expected/get_ddl/get_ddl_sequence.out 2>&1`;
ok( $? == 0, "diff for retrieving sequence ddl");

$ret = `diff results/get_ddl/get_ddl_routine.out test/expected/get_ddl/get_ddl_routine.out 2>&1`;
ok( $? == 0, "diff for retrieving routine ddl");

$ret = `diff results/get_ddl/get_ddl_trigger.out test/expected/get_ddl/get_ddl_trigger.out 2>&1`;
ok( $? == 0, "diff for retrieving trigger ddl");

$ret = `diff results/get_ddl/get_ddl_index_constraint.out test/expected/get_ddl/get_ddl_index_constraint.out 2>&1`;
ok( $? == 0, "diff for retrieving index and constraint ddl");

$ret = `diff results/get_ddl/get_ddl_type.out test/expected/get_ddl/get_ddl_type.out 2>&1`;
ok( $? == 0, "diff for retrieving type ddl");
